# Converts EmbeddingGemma to the Core ML model and tokenizer file the app uses.
# Needs Python 3.12 with torch 2.7, transformers 4.57, coremltools 9 and a Hugging Face login.
# After converting, clear the vectors in kb_chunks and run load_knowledge again.
import json
import shutil
import unicodedata
from pathlib import Path

import coremltools as ct
import numpy as np
from coremltools.converters.mil.frontend.torch import ops as ct_torch_ops
import torch
from huggingface_hub import snapshot_download
from safetensors.torch import load_file
from transformers import AutoModel, AutoTokenizer
from transformers.models.gemma3 import modeling_gemma3 as gemma3

MODEL_ID = "google/embeddinggemma-300m"
REVISION = "57c266a740f537b4dc058e1b0cda161fd15afa75"
QUERY_PROMPT = "task: search result | query: "
DOCUMENT_PROMPT = "title: none | text: "
MAX_TOKENS = 512
REPO = Path(__file__).resolve().parents[2]
RESOURCES = REPO / "CruzRoja/Resources"
NAME = "EmbeddingGemma"
SPECIAL = ("<pad>", "<eos>", "<bos>", "<unk>")


class Embedder(torch.nn.Module):
    def __init__(self, encoder, dense1: torch.Tensor, dense2: torch.Tensor):
        super().__init__()
        self.encoder = encoder
        self.dense1 = torch.nn.Linear(dense1.shape[1], dense1.shape[0], bias=False)
        self.dense1.weight.data = dense1
        self.dense2 = torch.nn.Linear(dense2.shape[1], dense2.shape[0], bias=False)
        self.dense2.weight.data = dense2

    def forward(self, input_ids, attention_mask):
        keep = attention_mask.to(torch.float32)
        # Same mask for every layer so any text length works
        additive = (1.0 - keep)[:, None, None, :] * torch.finfo(torch.float32).min
        mask = additive.expand(-1, 1, input_ids.shape[1], -1)
        positions = torch.cumsum(torch.ones_like(input_ids), dim=1) - 1
        hidden = self.encoder(
            input_ids=input_ids.long(), position_ids=positions.long(), cache_position=positions[0].long(),
            attention_mask={"full_attention": mask, "sliding_attention": mask}, use_cache=False,
        ).last_hidden_state
        pooled = (hidden * keep[..., None]).sum(dim=1) / keep.sum(dim=1, keepdim=True).clamp(min=1e-9)
        return torch.nn.functional.normalize(self.dense2(self.dense1(pooled)), dim=-1)


def rotate_half(x: torch.Tensor) -> torch.Tensor:
    # Rewritten because coremltools can't convert the original
    x1, x2 = x.chunk(2, dim=-1)
    return torch.cat((-x2, x1), dim=-1)


gemma3.rotate_half = rotate_half


def _cast(context, node, dtype, dtype_name):
    # Fixes a coremltools bug with NumPy 2
    from coremltools.converters.mil import Builder as mb
    x = ct_torch_ops._get_inputs(context, node, expected=1)[0]
    if x.can_be_folded_to_const():
        value = np.asarray(x.val)
        res = x if isinstance(x.val, dtype) else mb.const(val=dtype(value.item()), name=node.name)
    elif len(x.shape) > 0:
        res = mb.cast(x=mb.squeeze(x=x, name=node.name + "_item"), dtype=dtype_name, name=node.name)
    else:
        res = mb.cast(x=x, dtype=dtype_name, name=node.name)
    context.add(res, node.name)


ct_torch_ops._cast = _cast


def is_kept(piece: str) -> bool:
    if piece in SPECIAL or (piece.startswith("<0x") and len(piece) == 6):
        return True
    if piece.startswith("<") and piece.endswith(">"):
        return False
    return all(unicodedata.category(ch)[0] in "PNSZC" or "LATIN" in unicodedata.name(ch, "") or ch == "▁"
               for ch in piece)


def prune(snapshot: str, encoder) -> tuple[dict, dict[int, int]]:
    # Keeps only Latin pieces since the app only needs Spanish
    model = json.load(open(f"{snapshot}/tokenizer.json"))["model"]
    assert model["type"] == "BPE" and model["byte_fallback"] and not model["ignore_merges"]
    vocab = model["vocab"]
    keep = sorted(i for p, i in vocab.items() if is_kept(p))
    new_id = {old: new for new, old in enumerate(keep)}
    piece_of = {i: p for p, i in vocab.items()}
    merges = []
    for left, right in model["merges"]:
        ids = (vocab.get(left), vocab.get(right), vocab.get(left + right))
        if all(i in new_id for i in ids):
            merges.append([new_id[i] for i in ids])

    table = encoder.embed_tokens
    table.weight = torch.nn.Parameter(table.weight.data[torch.tensor(keep)].clone())
    table.num_embeddings = len(keep)
    tokenizer = {
        "pieces": [piece_of[i] for i in keep], "merges": merges,
        **{name: new_id[vocab[f"<{name}>"]] for name in ("pad", "eos", "bos", "unk")},
        "query_prompt": QUERY_PROMPT, "document_prompt": DOCUMENT_PROMPT, "max_tokens": MAX_TOKENS,
    }
    return tokenizer, new_id


def check_retrieval(mlmodel, tokenizer, new_id: dict[int, int]) -> None:
    # Checks that the converted model still finds the right topics
    import sys
    sys.path.insert(0, str(REPO / "backend"))
    from scripts.knowledge_content import CHUNKS
    evals = json.load(open(Path(__file__).with_name("retrieval_eval.json")))

    def embed(text):
        ids = [new_id[i] for i in tokenizer(text, truncation=True, max_length=MAX_TOKENS)["input_ids"]]
        out = mlmodel.predict({"input_ids": np.array([ids], dtype=np.int32),
                               "attention_mask": np.ones((1, len(ids)), dtype=np.int32)})
        return out["embedding"][0]

    documents = np.stack([embed(DOCUMENT_PROMPT + c["text"]) for c in CHUNKS])
    ids = [c["id"] for c in CHUNKS]
    top1 = top3 = 0
    for question in evals:
        ranked = np.argsort(-(documents @ embed(QUERY_PROMPT + question["q"])))[:3]
        found = [ids[j].startswith(question["topic"] + "-") for j in ranked]
        top1 += found[0]
        top3 += any(found)
    print(f"Retrieval on {len(evals)} questions: top 1 {top1}, top 3 {top3}")


def main() -> None:
    snapshot = snapshot_download(MODEL_ID, revision=REVISION)
    hf_tokenizer = AutoTokenizer.from_pretrained(snapshot)
    encoder = AutoModel.from_pretrained(snapshot, attn_implementation="eager", dtype=torch.float32).eval()
    tokenizer, new_id = prune(snapshot, encoder)
    embedder = Embedder(encoder, load_file(f"{snapshot}/2_Dense/model.safetensors")["linear.weight"],
                        load_file(f"{snapshot}/3_Dense/model.safetensors")["linear.weight"]).eval()

    example_ids = [new_id[i] for i in hf_tokenizer(DOCUMENT_PROMPT + "Hemorragia grave")["input_ids"]]
    example = torch.tensor([example_ids], dtype=torch.int32)
    with torch.no_grad():
        traced = torch.jit.trace(embedder, (example, torch.ones_like(example)))
    length = ct.RangeDim(lower_bound=1, upper_bound=MAX_TOKENS, default=64)
    mlmodel = ct.convert(
        traced,
        inputs=[ct.TensorType(name="input_ids", shape=(1, length), dtype=np.int32),
                ct.TensorType(name="attention_mask", shape=(1, length), dtype=np.int32)],
        outputs=[ct.TensorType(name="embedding", dtype=np.float32)],
        minimum_deployment_target=ct.target.iOS18,
        compute_precision=ct.precision.FLOAT32,
    )
    # 4-bit weights to make the model smaller
    from coremltools.optimize import coreml as opt
    weights = opt.OpLinearQuantizerConfig(mode="linear_symmetric", dtype="int4", granularity="per_block", block_size=32)
    mlmodel = opt.linear_quantize_weights(mlmodel, opt.OptimizationConfig(global_config=weights))

    identifier = f"{MODEL_ID}@{REVISION[:7]}+coreml-w4-latin"
    mlmodel.short_description = "EmbeddingGemma: mean-pooled, projected, L2-normalized sentence embedding"
    mlmodel.user_defined_metadata["identifier"] = identifier
    RESOURCES.mkdir(parents=True, exist_ok=True)
    package = RESOURCES / f"{NAME}.mlpackage"
    if package.exists():
        shutil.rmtree(package)
    mlmodel.save(str(package))
    (RESOURCES / f"{NAME}-tokenizer.json").write_text(json.dumps(tokenizer, ensure_ascii=False), encoding="utf-8")
    print(f"Saved {NAME}.mlpackage ({identifier}); {len(tokenizer['pieces'])} pieces, {len(tokenizer['merges'])} merges")

    check_retrieval(mlmodel, hf_tokenizer, new_id)


if __name__ == "__main__":
    main()
