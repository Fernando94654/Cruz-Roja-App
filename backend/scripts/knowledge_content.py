"""Initial content of the first-aid knowledge base.

Written as topics with fixed sections, then flattened into CHUNKS: the plain
id + text rows stored in kb_chunks. Each chunk starts with its topic and
section, so it stands alone when retrieved.

This is only the first import: after seeding, the rows in the database are the
source of truth and are edited there. load_knowledge.py never overwrites them.

Writing rules (see backend/README.md, "Knowledge base"):
- Mexican Spanish, "tú", short imperative sentences; one idea per step.
- Every instruction comes from a source in SOURCES; clinical steps follow the
  2024-2025 guidelines. Older Mexican material is vocabulary only.
- Everything is a draft until Cruz Roja reviews it against its official
  protocols (RF-16).
"""
from datetime import date

ACCESSED = date(2026, 11, 14)

SOURCES = [
    {
        "id": "erc-2025-fa",
        "title": "First Aid Guidelines 2025",
        "publisher": "Resuscitation Council UK, adaptación de European Resuscitation Council Guidelines 2025 First Aid",
        "edition": "27 de octubre de 2025",
        "url": "https://www.resus.org.uk/professional-library/2025-resuscitation-guidelines/first-aid-guidelines",
        "accessed_on": ACCESSED,
        "priority": 10,
    },
    {
        "id": "erc-2025-bls",
        "title": "Adult Basic Life Support Guidelines 2025",
        "publisher": "Resuscitation Council UK, adaptación de European Resuscitation Council Guidelines 2025",
        "edition": "27 de octubre de 2025",
        "url": "https://www.resus.org.uk/professional-library/2025-resuscitation-guidelines/adult-basic-life-support-guidelines",
        "accessed_on": ACCESSED,
        "priority": 10,
    },
    {
        "id": "erc-2025-pls",
        "title": "Paediatric Life Support Guidelines 2025 y algoritmo de atragantamiento pediátrico",
        "publisher": "Resuscitation Council UK, adaptación de European Resuscitation Council Guidelines 2025",
        "edition": "27 de octubre de 2025",
        "url": "https://www.resus.org.uk/professional-library/2025-resuscitation-guidelines/paediatric-basic-life-support-guidelines",
        "accessed_on": ACCESSED,
        "priority": 10,
    },
    {
        "id": "ilcor-2025-fa",
        "title": "2025 International Consensus on First Aid Science With Treatment Recommendations",
        "publisher": "International Liaison Committee on Resuscitation (ILCOR), First Aid Task Force",
        "edition": "2025",
        "url": "https://www.ilcor.org/uploads/FA-2025-COSTR-Full-Chapter.pdf",
        "accessed_on": ACCESSED,
        "priority": 20,
    },
    {
        "id": "cdc-convulsiones",
        "title": "First Aid for Seizures",
        "publisher": "Centers for Disease Control and Prevention (CDC)",
        "edition": "15 de mayo de 2024",
        "url": "https://www.cdc.gov/epilepsy/first-aid-for-seizures/index.html",
        "accessed_on": ACCESSED,
        "priority": 30,
    },
    {
        "id": "aap-intoxicacion",
        "title": "¿Qué hacer en el caso de una emergencia por envenenamiento?",
        "publisher": "American Academy of Pediatrics, HealthyChildren.org",
        "edition": "Actualizado el 21 de noviembre de 2015",
        "url": "https://www.healthychildren.org/spanish/safety-prevention/all-around/paginas/what-to-do-in-a-poisoning-emergency.aspx",
        "accessed_on": ACCESSED,
        "priority": 40,
    },
]


def steps(*lines: str) -> str:
    """Numbered steps, one per line, so they read well on screen and aloud."""
    return "\n".join(f"{n}. {line}" for n, line in enumerate(lines, start=1))


def lines(*items: str) -> str:
    return "\n".join(items)


TOPICS = [
    {
        "id": "evaluacion-inicial",
        "title": "Qué hacer primero en una emergencia",
        "source_ids": ["erc-2025-fa", "erc-2025-bls"],
        "sections": {
            "reconoce": (
                "Sirve cuando alguien se lastima o se pone mal de repente y no sabes por dónde empezar. "
                "Estos pasos te dicen qué revisar primero y cuándo pasar a otra guía, como RCP o hemorragia."
            ),
            "llama_911": (
                "Llama al 911 de inmediato si la persona no responde, no respira o respira raro (jadea o boquea), "
                "sangra mucho, tiene dolor de pecho, no puede hablar o mover un lado del cuerpo, o se está ahogando. "
                "Pon el teléfono en altavoz para tener las manos libres y sigue las indicaciones del operador."
            ),
            "que_hacer": steps(
                "Revisa que el lugar sea seguro para ti: tráfico, fuego, cables, gas o agua. Si no lo es, no te acerques.",
                "Acércate, toca sus hombros y pregúntale en voz alta si está bien.",
                "Si no responde, llama al 911 en altavoz antes de seguir revisando.",
                "Observa si respira normal, no más de 10 segundos. Jadear o boquear no es respirar normal.",
                "Si no respira normal, empieza RCP.",
                "Si respira pero no responde, ponlo de lado en posición de recuperación.",
                "Si responde, pregúntale qué pasó, busca sangrado fuerte y quédate con él.",
            ),
            "que_no_hacer": lines(
                "No te pongas en peligro: un segundo herido no ayuda a nadie.",
                "No muevas a una persona lastimada, salvo que el lugar sea peligroso.",
                "No le des de comer ni de beber.",
                "No uses equipo ni medicinas que no sepas usar.",
                "No cuelgues con el 911 hasta que el operador te lo indique.",
            ),
            "mientras_llega": (
                "Quédate con la persona, mantenla abrigada y tranquila. Vuelve a revisar si responde y si respira; "
                "si algo cambia, avísale al 911. Si hay más gente, pide que alguien busque un desfibrilador (DEA) "
                "y que otra persona espere a la ambulancia afuera para guiarla."
            ),
        },
    },
    {
        "id": "paro-cardiaco-rcp-adulto",
        "title": "Paro cardiaco: RCP en adultos",
        "source_ids": ["erc-2025-bls", "ilcor-2025-fa"],
        "sections": {
            "reconoce": (
                "La persona no responde cuando le hablas y la tocas, y no respira o respira de forma anormal: "
                "jadeos lentos, boqueadas o ruidos. Al inicio puede tener una sacudida parecida a una convulsión; "
                "revisa la respiración cuando termine. Si dudas, actúa como si fuera un paro cardiaco."
            ),
            "llama_911": (
                "Siempre. Llama al 911 en altavoz en cuanto veas que no responde, incluso antes de terminar de revisar "
                "si respira. El operador te guiará con la RCP. Si estás solo y sin teléfono, grita pidiendo ayuda; "
                "si nadie viene, ve a llamar y al regresar empieza la RCP."
            ),
            "que_hacer": steps(
                "Acuéstalo boca arriba sobre una superficie firme.",
                "Pon el talón de una mano en el centro del pecho y la otra encima, con los dedos entrelazados.",
                "Con los brazos rectos y los hombros sobre tus manos, empuja fuerte: de 5 a 6 cm de profundidad.",
                "Hazlo rápido, de 100 a 120 compresiones por minuto, y deja que el pecho regrese entre cada una.",
                "Si no sabes dar respiraciones, da solo compresiones sin parar. Si sabes, da 30 compresiones y 2 respiraciones.",
                "Pide un desfibrilador (DEA): préndelo, pega los parches en el pecho desnudo y sigue sus instrucciones de voz.",
            ),
            "que_no_hacer": lines(
                "No pierdas tiempo buscando el pulso.",
                "No te detengas a revisar si ya respira; sigue hasta que llegue ayuda.",
                "No tengas miedo de lastimarlo: sin RCP la persona muere, y el riesgo de dañarla es bajo.",
                "No toques a la persona mientras el DEA analiza o da la descarga.",
                "No lo pongas de lado mientras no respire normal.",
            ),
            "mientras_llega": (
                "Sigue con las compresiones hasta que llegue la ambulancia, la persona despierte y respire normal, "
                "o ya no puedas más. Si hay alguien más que sepa, túrnense para no cansarse, sin dejar pausas largas. "
                "Después de una descarga del DEA, vuelve a comprimir de inmediato y sigue sus indicaciones."
            ),
        },
    },
    {
        "id": "rcp-ninos-bebes",
        "title": "RCP en niños y bebés",
        "source_ids": ["erc-2025-pls"],
        "sections": {
            "reconoce": (
                "Bebé es menor de 1 año; niño, de 1 a 12 años. Necesita RCP si no responde cuando le hablas y lo tocas "
                "y no respira normal. Revisa la respiración no más de 10 segundos. Para despertarlo, háblale y tócalo; "
                "nunca lo lastimes."
            ),
            "llama_911": (
                "Siempre. Llama al 911 en altavoz de inmediato y empieza la RCP mientras hablas con el operador. "
                "Si estás solo, llama y empieza la RCP antes de ir por un desfibrilador."
            ),
            "que_hacer": steps(
                "Acuéstalo boca arriba sobre algo firme. Inclina su cabeza hacia atrás y levanta su barbilla; en bebés, deja la cabeza recta.",
                "Da 5 respiraciones de rescate: cubre su boca (en bebés, boca y nariz) y sopla lo justo para que el pecho se levante.",
                "Empieza las compresiones en la mitad inferior del esternón, hundiendo un tercio del pecho.",
                "Bebé: rodea su pecho con las manos y comprime con los dos pulgares. Niño: usa una o dos manos.",
                "Ritmo: de 100 a 120 compresiones por minuto.",
                "Alterna 30 compresiones y 2 respiraciones sin detenerte.",
            ),
            "que_no_hacer": lines(
                "No lo sacudas para despertarlo.",
                "No lo pellizques ni lo lastimes para ver si reacciona.",
                "No hundas el pecho más de 6 cm, ni siquiera en adolescentes.",
                "No te detengas a revisar si ya respira; sigue hasta que llegue ayuda.",
            ),
            "casos_especiales": (
                "Adolescentes (13 a 18 años): haz la RCP como en adultos, de 5 a 6 cm de profundidad. "
                "Desfibrilador (DEA): úsalo también en niños; si tiene modo pediátrico, actívalo en menores de 25 kg. "
                "En niños pequeños pon un parche en el centro del pecho y el otro en la espalda, entre los omóplatos. "
                "Si no puedes dar respiraciones, da solo compresiones: es mucho mejor que no hacer nada."
            ),
            "mientras_llega": (
                "Sigue con la RCP hasta que llegue la ambulancia, el niño reaccione y respire normal, o ya no puedas más. "
                "Si empieza a respirar normal pero no despierta, ponlo de lado y vigila su respiración sin parar."
            ),
        },
    },
    {
        "id": "atragantamiento-adulto-nino",
        "title": "Atragantamiento en adultos y niños",
        "source_ids": ["erc-2025-fa", "erc-2025-pls", "ilcor-2025-fa"],
        "sections": {
            "reconoce": (
                "De repente no puede hablar, toser ni respirar, sobre todo mientras come. Puede llevarse las manos al "
                "cuello y ponerse morado. Si puede toser con fuerza y hablar, la obstrucción es parcial: anímalo a "
                "seguir tosiendo y vigílalo."
            ),
            "llama_911": (
                "Llama al 911 si la tos no sirve, si después de 5 golpes y 5 compresiones el objeto no sale, o si "
                "pierde el conocimiento. Usa el altavoz para seguir ayudando mientras hablas."
            ),
            "que_hacer": steps(
                "Pregúntale: ¿te estás atragantando? Si puede toser, anímalo a toser fuerte.",
                "Si no puede toser, inclínalo hacia adelante y da hasta 5 golpes firmes entre los omóplatos con el talón de la mano.",
                "Si no sale, ponte detrás, pon tu puño entre el ombligo y la punta del esternón, cúbrelo con la otra mano y jala hacia adentro y hacia arriba, hasta 5 veces.",
                "Si sigue atorado, llama al 911 y alterna 5 golpes y 5 compresiones hasta que salga o pierda el conocimiento.",
                "Si pierde el conocimiento, acuéstalo, confirma que alguien llamó al 911 y empieza RCP.",
            ),
            "que_no_hacer": lines(
                "No metas los dedos a ciegas en su boca; saca el objeto solo si lo ves claramente.",
                "No le des agua ni pan para empujar el objeto.",
                "No lo dejes solo, aunque parezca mejorar.",
                "No hagas compresiones abdominales a bebés menores de 1 año.",
            ),
            "casos_especiales": (
                "Bebés menores de 1 año: usa la técnica para bebés, con golpes en la espalda y compresiones en el pecho. "
                "Embarazadas o personas a las que no alcanzas a rodear con los brazos: haz las compresiones en el "
                "centro del pecho en lugar del abdomen."
            ),
            "mientras_llega": (
                "Aunque el objeto salga, quien recibió compresiones abdominales o de pecho debe ser revisado por un "
                "médico, porque pueden causar lesiones internas. Vigila que respire bien y que recupere su color."
            ),
        },
    },
    {
        "id": "atragantamiento-bebe",
        "title": "Atragantamiento en bebés",
        "source_ids": ["erc-2025-pls", "ilcor-2025-fa"],
        "sections": {
            "reconoce": (
                "El bebé (menor de 1 año) de repente no puede llorar, toser ni respirar, hace ruidos agudos o se pone "
                "morado. Si tose con fuerza o llora, la obstrucción es parcial: déjalo toser y vigílalo de cerca."
            ),
            "llama_911": (
                "Llama al 911 en altavoz en cuanto la tos no sirva, y sigue ayudando al bebé mientras hablas con el operador."
            ),
            "que_hacer": steps(
                "Acuesta al bebé boca abajo sobre tu antebrazo, con la cabeza más baja que el pecho, sosteniendo su mandíbula con tu mano.",
                "Da hasta 5 golpes firmes entre los omóplatos con el talón de tu mano.",
                "Si no sale, voltéalo boca arriba sobre tu brazo o tu muslo, con la cabeza más baja.",
                "Rodea su pecho con tus manos y da hasta 5 compresiones con los dos pulgares en el centro del pecho.",
                "Alterna 5 golpes y 5 compresiones hasta que salga el objeto o deje de responder.",
                "Si deja de responder, acuéstalo en una superficie firme, da 5 respiraciones y empieza RCP de bebé.",
            ),
            "que_no_hacer": lines(
                "No le hagas compresiones abdominales (maniobra de Heimlich) a un bebé.",
                "No metas los dedos a ciegas en su boca; saca el objeto solo si lo ves claramente.",
                "No lo cuelgues de los pies ni lo sacudas.",
                "No le des agua ni leche para empujar el objeto.",
            ),
            "mientras_llega": (
                "Aunque el objeto salga, llévalo a revisión médica. Vigila que respire bien, que llore con normalidad "
                "y que su color regrese."
            ),
        },
    },
    {
        "id": "hemorragia-grave",
        "title": "Hemorragia grave",
        "source_ids": ["erc-2025-fa", "ilcor-2025-fa"],
        "sections": {
            "reconoce": (
                "Sangre que sale a chorro o a borbotones, que empapa rápido la ropa o las telas, o que forma un charco. "
                "La persona puede ponerse pálida, sudorosa, confundida o somnolienta: son señales de choque y de que "
                "está perdiendo demasiada sangre."
            ),
            "llama_911": (
                "Siempre. Llama al 911 en altavoz, o pide a alguien que llame, mientras tú presionas la herida. "
                "No sueltes la presión para llamar."
            ),
            "que_hacer": steps(
                "Si tienes a la mano guantes o una bolsa de plástico, protege tus manos, sin perder tiempo.",
                "Presiona fuerte y directo sobre la herida con tus manos, una gasa o cualquier tela limpia.",
                "Si la herida es profunda, mete la gasa o la tela dentro de la herida y sigue presionando.",
                "Si la tela se empapa, no la quites: pon más encima y presiona más fuerte.",
                "Cuando deje de sangrar, véndala firme para mantener la presión.",
                "Si es en un brazo o una pierna y no se detiene con presión, pon un torniquete lo antes posible.",
            ),
            "que_no_hacer": lines(
                "No retires la tela empapada de sangre.",
                "No aflojes ni quites un torniquete; solo el personal médico puede hacerlo.",
                "No pongas el torniquete sobre una articulación, como el codo o la rodilla.",
                "No presiones puntos lejos de la herida en lugar de presionar la herida.",
                "No saques objetos clavados; presiona alrededor de ellos.",
            ),
            "casos_especiales": (
                "Torniquete, solo en brazos o piernas: colócalo de 5 a 7 cm arriba de la herida, nunca sobre una "
                "articulación. Apriétalo hasta que deje de sangrar; va a doler. Anota la hora en que lo pusiste. Si sigue "
                "sangrando, pon un segundo torniquete arriba del primero. En niños se recomienda un torniquete comercial. "
                "Herida en el pecho: déjala descubierta y presiona solo donde sangra."
            ),
            "mientras_llega": (
                "Mantén la presión sin soltarla. Acuesta a la persona y abrígala para que no pierda calor. "
                "No le des de beber. Si deja de responder y no respira normal, empieza RCP."
            ),
        },
    },
    {
        "id": "inconsciente-respira",
        "title": "Persona inconsciente que respira",
        "source_ids": ["erc-2025-fa", "ilcor-2025-fa"],
        "sections": {
            "reconoce": (
                "No responde o responde muy poco cuando le hablas y lo tocas, pero respira normal. "
                "Si no respira o solo jadea, este no es el caso: empieza RCP."
            ),
            "llama_911": "Siempre. Llama al 911 en altavoz y explica que la persona no responde pero respira.",
            "que_hacer": steps(
                "Arrodíllate a su lado. Quítale los lentes y los objetos grandes de los bolsillos.",
                "Pon el brazo más cercano a ti en ángulo recto, con la palma hacia arriba.",
                "Cruza su otro brazo sobre el pecho y apoya el dorso de su mano contra su mejilla.",
                "Dobla su rodilla más lejana y jala de ella para girarlo hacia ti, de lado.",
                "Inclina su cabeza un poco hacia atrás para que el aire pase bien.",
                "Revisa su respiración sin parar.",
            ),
            "que_no_hacer": lines(
                "No lo pongas de lado si jadea o si dudas que respire: empieza RCP.",
                "No lo muevas si tuvo un golpe fuerte, una caída o un choque, salvo que vomite o no puedas mantener libre su vía aérea.",
                "No le des nada de comer ni de beber.",
                "No lo dejes solo.",
            ),
            "mientras_llega": (
                "Vigila su respiración todo el tiempo. Si deja de respirar normal, o si de lado no puedes ver bien si "
                "respira, ponlo boca arriba, revisa de nuevo y empieza RCP si hace falta."
            ),
        },
    },
    {
        "id": "dolor-de-pecho-infarto",
        "title": "Dolor de pecho o posible infarto",
        "source_ids": ["erc-2025-fa", "ilcor-2025-fa"],
        "sections": {
            "reconoce": (
                "Dolor, presión u opresión en el pecho que puede irse al brazo, el cuello, la mandíbula o la espalda. "
                "Puede venir con falta de aire, sudor frío, náusea o mareo. En mujeres, adultos mayores y personas con "
                "diabetes a veces solo se siente como cansancio, falta de aire o malestar."
            ),
            "llama_911": "Siempre. Llama al 911 de inmediato; no esperes a ver si se le pasa.",
            "que_hacer": steps(
                "Tranquilízalo y ayúdalo a sentarse o acostarse en la posición que le sea más cómoda.",
                "Llama al 911.",
                "Si es adulto y no es alérgico a la aspirina, dale 300 mg de aspirina para que la mastique lo antes posible.",
                "Si ya tiene diagnóstico de angina y su medicamento (nitroglicerina), ayúdalo a usarlo.",
                "Quédate con él hasta que llegue la ayuda.",
            ),
            "que_no_hacer": lines(
                "No le des aspirina si es alérgico a ella, si es menor de edad o si el dolor viene de un golpe o accidente.",
                "No lo dejes caminar ni hacer esfuerzo.",
                "No esperes a ver si se le pasa.",
            ),
            "mientras_llega": (
                "Vigila si responde y si respira. Si pierde el conocimiento y no respira normal, empieza RCP y pide "
                "que alguien busque un desfibrilador (DEA)."
            ),
        },
    },
    {
        "id": "evc-derrame-cerebral",
        "title": "Derrame cerebral (EVC)",
        "source_ids": ["erc-2025-fa", "ilcor-2025-fa"],
        "sections": {
            "reconoce": (
                "Revisa tres cosas. Rostro: pídele que sonría; ¿se cae un lado de la cara? Brazos: pídele que levante "
                "los dos; ¿uno se cae o no lo puede mover? Habla: pídele que repita una frase; ¿habla raro o no entiende? "
                "Si ves cualquiera de estas señales, es tiempo de llamar al 911."
            ),
            "llama_911": (
                "Siempre, aunque las señales se quiten. Cada minuto cuenta: el tratamiento funciona mejor entre más "
                "pronto llegue al hospital. Dile al operador a qué hora empezaron los síntomas o a qué hora lo viste "
                "bien por última vez."
            ),
            "que_hacer": steps(
                "Llama al 911.",
                "Anota la hora en que empezaron los síntomas.",
                "Mantenlo en reposo, cómodo y acompañado.",
                "Si deja de responder pero respira, ponlo de lado en posición de recuperación.",
                "Si no respira normal, empieza RCP.",
                "Junta sus medicamentos para enseñárselos al personal de la ambulancia.",
            ),
            "que_no_hacer": lines(
                "No le des de comer, beber ni medicamentos, ni siquiera aspirina; puede no tragar bien.",
                "No esperes a ver si mejora.",
                "No lo acuestes a dormir para que se le pase.",
            ),
            "mientras_llega": (
                "Quédate con él, háblale con calma y vigila si responde y si respira. Si cambia algo, avísale al 911."
            ),
        },
    },
    {
        "id": "anafilaxia",
        "title": "Reacción alérgica grave (anafilaxia)",
        "source_ids": ["erc-2025-fa", "ilcor-2025-fa"],
        "sections": {
            "reconoce": (
                "Aparece minutos después de comer algo, una picadura o un medicamento. Sospecha anafilaxia si tiene "
                "dificultad para respirar (silbido o ruido al respirar), hinchazón de cara, labios o lengua, ronchas o "
                "enrojecimiento, piel fría y sudorosa, sensación de desmayo, o dolor de estómago, vómito o diarrea."
            ),
            "llama_911": "Siempre, aunque ya se haya aplicado su autoinyector y se sienta mejor.",
            "que_hacer": steps(
                "Llama al 911.",
                "Si tiene autoinyector de epinefrina (adrenalina), úsalo de inmediato en la parte externa del muslo. Puede aplicárselo él mismo.",
                "Acuéstalo. Si le cuesta respirar, déjalo sentado con las piernas estiradas.",
                "Aleja la causa si se puede, por ejemplo el aguijón o la comida.",
                "Si a los 5 minutos no mejora, aplica un segundo autoinyector, de preferencia en la otra pierna.",
            ),
            "que_no_hacer": lines(
                "No esperes a que empeore para usar el autoinyector.",
                "No lo pongas de pie ni lo hagas caminar, aunque se sienta mejor.",
                "No le des de comer ni de beber.",
                "No uses medicamentos que no sepas usar. Un antialérgico en pastilla no sustituye a la epinefrina.",
            ),
            "mientras_llega": (
                "Quédate con él y vigila su respiración. Si deja de responder y no respira normal, empieza RCP. "
                "Entrega el autoinyector usado al personal de la ambulancia y diles a qué hora lo aplicaste."
            ),
        },
    },
    {
        "id": "convulsiones",
        "title": "Convulsiones",
        "source_ids": ["cdc-convulsiones"],
        "sections": {
            "reconoce": (
                "Pierde el conocimiento, el cuerpo se pone rígido y brazos y piernas se sacuden. Puede morderse la "
                "lengua, babear o perder el control de la orina. Al terminar suele quedar confundido o con sueño."
            ),
            "llama_911": (
                "Llama al 911 si la convulsión dura más de 5 minutos, si le da otra poco después, si le cuesta respirar "
                "o no despierta al terminar, si se lastimó, si pasó en el agua, si es su primera convulsión, si tiene "
                "diabetes y perdió el conocimiento, o si está embarazada."
            ),
            "que_hacer": steps(
                "Si ves que va a caer, ayúdalo a bajar al suelo.",
                "Aleja los objetos con los que se pueda golpear.",
                "Pon algo suave y plano bajo su cabeza, como una chamarra doblada.",
                "Quítale los lentes y afloja lo que apriete su cuello.",
                "Gíralo con cuidado de lado, con la boca hacia el suelo.",
                "Toma el tiempo que dura la convulsión.",
            ),
            "que_no_hacer": lines(
                "No lo sujetes ni intentes detener sus movimientos.",
                "No le metas nada a la boca, ni tus dedos ni una cuchara: no se va a tragar la lengua.",
                "No le des respiración de boca a boca durante la convulsión; normalmente vuelve a respirar solo.",
                "No le des agua ni comida hasta que esté completamente alerta.",
            ),
            "mientras_llega": (
                "Cuando termine, déjalo de lado y quédate con él hasta que despierte por completo. Háblale con calma y "
                "explícale qué pasó. Busca si trae una pulsera o tarjeta médica. Si no respira normal, empieza RCP."
            ),
        },
    },
    {
        "id": "ahogamiento",
        "title": "Ahogamiento en el agua",
        "source_ids": ["erc-2025-fa"],
        "sections": {
            "reconoce": (
                "Una persona en el agua que no puede mantenerse a flote, o alguien que sacaron del agua y no responde "
                "o no respira normal. En niños puede pasar en segundos y en muy poca agua, como una tina o una cubeta."
            ),
            "llama_911": "Siempre. Llama al 911 antes de intentar cualquier rescate, o pide a alguien que llame.",
            "que_hacer": steps(
                "Si no estás entrenado en rescate acuático, no te metas al agua.",
                "Desde la orilla, alcánzale algo que flote o con qué jalarlo: un salvavidas, una cuerda, una rama o una hielera.",
                "Ya fuera del agua, si no responde y no respira normal, da primero 5 respiraciones de rescate.",
                "Después sigue con RCP: 30 compresiones y 2 respiraciones.",
                "Si hay un desfibrilador (DEA), seca rápido el pecho y sigue sus instrucciones.",
            ),
            "que_no_hacer": lines(
                "No te lances al agua si no sabes rescatar: es común que también se ahogue quien intenta ayudar.",
                "No intentes sacarle el agua de los pulmones ni presiones su abdomen.",
                "No pierdas tiempo antes de las respiraciones de rescate.",
            ),
            "mientras_llega": (
                "Sigue la RCP hasta que llegue ayuda o respire normal. Si respira, quítale la ropa mojada, abrígalo y "
                "ponlo de lado. Aunque parezca recuperado, debe revisarlo un médico."
            ),
        },
    },
    {
        "id": "golpe-de-calor",
        "title": "Golpe de calor",
        "source_ids": ["erc-2025-fa", "ilcor-2025-fa"],
        "sections": {
            "reconoce": (
                "Después de estar en calor intenso o de hacer ejercicio fuerte: confusión, agitación, desorientación, "
                "convulsiones o pérdida del conocimiento. La piel suele estar muy caliente. Puede pasar aunque no haga "
                "tanto calor si la persona hizo un gran esfuerzo."
            ),
            "llama_911": "Siempre. Llama al 911 y empieza a enfriarlo de inmediato, sin esperar a la ambulancia.",
            "que_hacer": steps(
                "Sácalo del calor a un lugar fresco o a la sombra.",
                "Quítale la ropa que sobre.",
                "Empieza a enfriarlo ya con lo que tengas. Lo mejor es meter su cuerpo, del cuello para abajo, en agua fría.",
                "Si no se puede, usa regadera fría, sábanas o toallas mojadas con hielo, bolsas de hielo, o mójalo y ponle un ventilador.",
                "Sigue enfriando 15 minutos o hasta que se le quite la confusión, lo que pase primero.",
                "Primero enfría y después traslada; sigue enfriándolo en el camino.",
            ),
            "que_no_hacer": lines(
                "No esperes a la ambulancia para empezar a enfriarlo.",
                "No le des de beber si está confundido o inconsciente.",
                "No le des medicinas para la fiebre; no sirven en un golpe de calor.",
            ),
            "mientras_llega": (
                "Si está despierto y puede tragar, dale agua o suero oral a sorbos. Si pierde el conocimiento pero "
                "respira, ponlo de lado. Si no respira normal, empieza RCP."
            ),
        },
    },
    {
        "id": "quemaduras",
        "title": "Quemaduras",
        "source_ids": ["ilcor-2025-fa", "aap-intoxicacion"],
        "sections": {
            "reconoce": (
                "Piel roja, con ampollas, o de color blanco, café o negro después de tocar fuego, líquidos calientes, "
                "aceite, vapor, objetos calientes, químicos o electricidad."
            ),
            "llama_911": (
                "Llama al 911 si la quemadura es grande o profunda (piel blanca, café o negra), si está en la cara, las "
                "manos, los pies, los genitales o las articulaciones, si fue por electricidad o químicos, si respiró humo "
                "o tiene la voz ronca, o si es un bebé o un adulto mayor."
            ),
            "que_hacer": steps(
                "Detén la quemadura: aleja la fuente de calor. Si su ropa arde, que se tire al suelo y ruede, o cúbrelo con una manta.",
                "Enfría de inmediato con agua corriente fresca, no helada. Mantén el agua al menos 10 minutos, de preferencia 20.",
                "Mientras enfrías, quita anillos, relojes y ropa de la zona, solo si no están pegados a la piel.",
                "Cubre con plástico de cocina limpio, sin apretar, o con una gasa que no se pegue.",
            ),
            "que_no_hacer": lines(
                "No pongas hielo, pasta de dientes, mantequilla, aceite, clara de huevo, café, jitomate ni cremas.",
                "No revientes las ampollas.",
                "No despegues la ropa que esté pegada a la piel.",
                "No uses algodón ni telas que suelten pelusa.",
            ),
            "casos_especiales": (
                "Bebés y niños pequeños: enfría solo la zona quemada y vigila que no se enfríe todo su cuerpo; si tiembla "
                "o tiene la piel fría, abrígalo. Químicos: quita la ropa contaminada y lava la piel con abundante agua al "
                "menos 15 minutos. Electricidad: corta la corriente antes de tocarlo; aunque la quemadura se vea pequeña, "
                "llama al 911."
            ),
            "mientras_llega": (
                "Mantén abrigado el resto del cuerpo. Vigila si respira bien, sobre todo si estuvo cerca de humo. "
                "No le des medicamentos sin indicación médica."
            ),
        },
    },
    {
        "id": "intoxicacion-envenenamiento",
        "title": "Intoxicación o envenenamiento",
        "source_ids": ["aap-intoxicacion", "erc-2025-fa", "ilcor-2025-fa"],
        "sections": {
            "reconoce": (
                "Tragó, respiró o se echó encima algo dañino: medicamentos, productos de limpieza, químicos, plantas, "
                "gas o humo. Puede tener vómito, somnolencia, confusión, dificultad para respirar, quemaduras en la boca, "
                "convulsiones, o no tener ningún síntoma todavía."
            ),
            "llama_911": (
                "Llama al 911 de inmediato si no responde, no respira, tiene convulsiones o temblores, o le cuesta "
                "respirar. Si no tiene síntomas, llama también al 911 o ve a urgencias y explica qué tomó, cuánto y "
                "a qué hora."
            ),
            "que_hacer": steps(
                "Retira el producto. Si todavía tiene algo en la boca, que lo escupa.",
                "Guarda el envase, la etiqueta o las pastillas para enseñarlos al 911 y al médico.",
                "Anota qué tomó, cuánto, a qué hora, y su edad y peso aproximados.",
                "Gas o humo: llévalo al aire libre de inmediato, sin ponerte en riesgo.",
                "En la piel: quita la ropa contaminada y lava con agua tibia al menos 15 minutos.",
                "En los ojos: mantén el párpado abierto y enjuaga con agua tibia del lagrimal hacia afuera durante 15 minutos.",
            ),
            "que_no_hacer": lines(
                "No lo hagas vomitar: ni con los dedos, ni con agua con sal, ni con jarabe de ipecacuana.",
                "No le des remedios caseros ni supuestos antídotos.",
                "No pongas pomadas ni grasas en la piel o en los ojos.",
                "No entres a un lugar con gas o humo si no tienes protección.",
            ),
            "casos_especiales": (
                "Sobredosis de opioides (fentanilo, heroína, morfina): respira muy lento o nada, está muy somnoliento o "
                "no responde, y tiene las pupilas muy pequeñas. Llama al 911. Si no respira normal, empieza RCP. "
                "Si tienes naloxona y sabes usarla, aplícala y sigue las instrucciones del empaque."
            ),
            "mientras_llega": (
                "Si no responde pero respira, ponlo de lado. Si deja de respirar, empieza RCP. Quédate con él y "
                "entrega el envase al personal de la ambulancia."
            ),
        },
    },
    {
        "id": "shock",
        "title": "Choque (shock)",
        "source_ids": ["erc-2025-fa", "ilcor-2025-fa"],
        "sections": {
            "reconoce": (
                "Después de un sangrado, una quemadura grave, una reacción alérgica o una infección: piel pálida, fría y "
                "sudorosa, respiración rápida, sed, mareo, confusión, angustia o somnolencia. Es una emergencia: al cuerpo "
                "no le está llegando suficiente sangre."
            ),
            "llama_911": "Siempre. Llama al 911 en altavoz y atiende la causa mientras llega la ayuda.",
            "que_hacer": steps(
                "Atiende la causa: presiona fuerte si sangra; si es una reacción alérgica grave, usa su autoinyector.",
                "Acuéstalo boca arriba.",
                "Si no tiene golpes ni fracturas, puedes levantar sus piernas unos 30 cm mientras llega la ambulancia.",
                "Abrígalo con una manta o chamarra, también por debajo si está en el suelo frío.",
                "Tranquilízalo y no lo dejes solo.",
            ),
            "que_no_hacer": lines(
                "No le des de comer ni de beber, aunque tenga sed.",
                "No lo dejes caminar.",
                "No levantes sus piernas si tiene golpes en la cabeza, el cuello, la espalda, la cadera o las piernas, o si le cuesta respirar.",
            ),
            "mientras_llega": (
                "Vigila si responde y si respira. Si pierde el conocimiento pero respira, ponlo de lado. Si no respira "
                "normal, empieza RCP."
            ),
        },
    },
]


SECTION_LABELS = {
    "reconoce": "Cómo reconocerlo",
    "llama_911": "Cuándo llamar al 911",
    "que_hacer": "Qué hacer",
    "que_no_hacer": "Qué no hacer",
    "casos_especiales": "Casos especiales",
    "mientras_llega": "Mientras llega la ambulancia",
}


# Two chunks per topic: how to recognize it and when to call 911, then what to do and not do.
# Measured with multilingual-e5-small on tools/embedding-model/retrieval_eval.json, this retrieves the right
# topic more often than one chunk per section (too similar across topics) or one per topic (too long).
CHUNK_PARTS = {
    "reconocer": ("reconoce", "llama_911"),
    "atender": ("que_hacer", "que_no_hacer", "casos_especiales", "mientras_llega"),
}


def flatten(topics: list[dict]) -> list[dict]:
    """The topic sections grouped into CHUNK_PARTS, each chunk starting with the topic's title."""
    chunks = []
    for topic in topics:
        for part, kinds in CHUNK_PARTS.items():
            sections = [f"{SECTION_LABELS[k]}:\n{topic['sections'][k].strip()}" for k in kinds if k in topic["sections"]]
            if sections:
                chunks.append({"id": f"{topic['id']}-{part}", "topic": topic["id"],
                               "text": topic["title"] + "\n" + "\n".join(sections)})
    return chunks


CHUNKS = flatten(TOPICS)
