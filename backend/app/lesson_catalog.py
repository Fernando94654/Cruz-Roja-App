"""Stable associations for the four curated lessons; never match by display title."""
from dataclasses import dataclass
from uuid import UUID


@dataclass(frozen=True)
class CuratedLesson:
    id: UUID
    guide_id: str
    video_id: str
    title: str
    description: str
    position: int
    previous_title: str
    previous_description: str
    previous_duration: int
    publisher: str
    steps: tuple[str, ...]

    @property
    def values(self) -> dict:
        return dict(title=self.title, description=self.description,
                    duration_seconds=None, video_url=f"https://www.youtube.com/watch?v={self.video_id}",
                    position=self.position, publisher=self.publisher, steps=list(self.steps))

    @property
    def previous_values(self) -> dict:
        return dict(title=self.previous_title, description=self.previous_description,
                    duration_seconds=self.previous_duration, video_url=None, position=self.position,
                    publisher=None, steps=[])

    @property
    def previous_video_values(self) -> dict:
        # Records populated by the video-only update, before metadata columns existed.
        return {**self.values, "publisher": None, "steps": []}


CATALOG = (
    CuratedLesson(UUID("e0509eb5-e732-4a8d-ac14-af41b4b3e3ed"), "cardiac_arrest", "7SBBka5fwW8",
                  "RCP con las manos", "Cómo dar compresiones en el pecho a un adulto que no respira mientras llega la ambulancia.",
                  1, "CPR", "How to give chest compressions to an adult who isn't breathing while the ambulance arrives.", 272, "CRUZ ROJA MEXICANA IAP",
                  ("Coloca las manos en el centro del pecho.",
                   "Comprime al menos cinco centímetros, de cien a ciento veinte veces por minuto.",
                   "Deja que el pecho regrese por completo entre compresiones.",
                   "No te detengas hasta que llegue ayuda o la persona responda.")),
    CuratedLesson(UUID("ee8c8787-42da-4aae-8b18-d2a0180622ed"), "choking", "s_skKO8Xyxs",
                  "Asfixia por atragantamiento", "Qué hacer si alguien no puede respirar, toser ni hablar.",
                  2, "Choking", "What to do if someone can't breathe, cough or speak.", 190, "CRUZ ROJA MEXICANA IAP",
                  ("Reconoce la señal: manos en el cuello y sin poder hablar.",
                   "Da cinco golpes en la espalda y luego cinco compresiones abdominales.",
                   "En embarazadas o personas con obesidad, comprime en el pecho.")),
    CuratedLesson(UUID("94b0b4d8-dcf4-422a-a304-af86d4918663"), "bleeding", "p7UNkf-06EY",
                  "Atención de hemorragias", "Cómo controlar un sangrado con presión directa.",
                  3, "Bleeding", "How to control bleeding with direct pressure.", 165, "CRUZ ROJA MEXICANA IAP",
                  ("Presiona firme y directo con una tela limpia.",
                   "Si se empapa, agrega más tela sin quitar la primera.",
                   "El torniquete solo se usa en brazos o piernas cuando la presión no funciona.")),
    CuratedLesson(UUID("e2104370-1408-4e6b-ac32-f226b54996ad"), "burn", "cECkv6xUuTY",
                  "Atención de heridas y quemaduras", "Primeros pasos ante heridas y quemaduras.",
                  4, "Burns", "First steps for minor and severe burns.", 185, "CRUZ ROJA MEXICANA IAP",
                  ("Enfría con agua corriente al menos diez minutos.",
                   "No uses hielo, mantequilla ni pasta de dientes.",
                   "Cubre con un apósito limpio y no revientes las ampollas.")),
)
BY_ID = {lesson.id: lesson for lesson in CATALOG}
