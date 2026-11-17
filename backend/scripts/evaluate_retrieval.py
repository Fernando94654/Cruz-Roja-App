# Checks how often the search finds the right topic for the test questions.
# Run with: python -m scripts.evaluate_retrieval
import json

from scripts.load_knowledge import BUNDLED, REPO, embed


def main() -> None:
    chunks = json.loads(BUNDLED.read_text(encoding="utf-8"))
    questions = json.loads((REPO / "tools/embedding-model/retrieval_eval.json").read_text(encoding="utf-8"))
    model, vectors = embed({str(i): q["q"] for i, q in enumerate(questions)}, query=True)
    top1 = top3 = 0
    for i, question in enumerate(questions):
        ranked = sorted(chunks, key=lambda c: -sum(a * b for a, b in zip(vectors[str(i)], c["embedding"])))
        found = [c["id"].startswith(question["topic"] + "-") for c in ranked[:3]]
        top1 += found[0]
        top3 += any(found)
        if not found[0]:
            print(f'  "{question["q"]}" -> {ranked[0]["id"]}')
    print(f"{model}: top 1 {top1}/{len(questions)}, top 3 {top3}/{len(questions)}")


if __name__ == "__main__":
    main()
