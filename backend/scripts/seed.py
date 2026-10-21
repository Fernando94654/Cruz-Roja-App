"""Development data mirroring the SwiftUI mockup."""

import uuid
from datetime import date, datetime, timedelta, timezone

from argon2 import PasswordHasher
from sqlalchemy import text

from app.crypto import encrypt_list
from app.db import SessionLocal
from app.models import (
    Circle,
    CircleMember,
    CommunityReport,
    EmergencyContact,
    Lesson,
    MedicalProfile,
    OfficialAlert,
    User,
    UserLocation,
)
from app.models.alerts import CommunityReportType, Severity
from app.models.circles import CircleRole
from app.models.medical import BloodType


# Same id as APIConfig.demoUserID in the iOS app
DEMO_USER_ID = uuid.UUID("00000000-0000-4000-8000-000000000001")


def point(lat: float, lng: float) -> str:
    return f"SRID=4326;POINT({lng} {lat})"


def main():
    now = datetime.now(timezone.utc)
    password = PasswordHasher().hash("demo1234")

    with SessionLocal.begin() as s:
        s.execute(text("TRUNCATE users, official_alerts, lessons CASCADE"))

        me = User(id=DEMO_USER_ID, email="user@example.com", password_hash=password, name="Demo User")
        family = [
            (User(email="mom@example.com", password_hash=password, name="Mom"), 25.6600, -100.3000),
            (User(email="dad@example.com", password_hash=password, name="Dad"), 25.6450, -100.2800),
            (User(email="sister@example.com", password_hash=password, name="Sister"), 25.6700, -100.3100),
        ]
        s.add_all([me, *(u for u, _, _ in family)])
        s.flush()

        s.add(MedicalProfile(
            user_id=me.id,
            full_name="María López",
            date_of_birth=date(1958, 3, 14),
            blood_type=BloodType.o_pos,
            allergies=encrypt_list(["Penicilina"]),
            conditions=encrypt_list(["Asma"]),
            medications=encrypt_list(["Salbutamol"]),
        ))
        s.add(EmergencyContact(user_id=me.id, name="Ana López", relationship="Hija", phone="8112345678"))

        circle = Circle(name="Family", created_by=me.id)
        s.add(circle)
        s.flush()
        s.add(CircleMember(circle_id=circle.id, user_id=me.id, role=CircleRole.admin))
        s.add(UserLocation(user_id=me.id, location=point(25.6516, -100.2895)))
        for u, lat, lng in family:
            s.add(CircleMember(circle_id=circle.id, user_id=u.id))
            s.add(UserLocation(user_id=u.id, location=point(lat, lng)))

        s.add(OfficialAlert(
            source="Civil Protection",
            type="rain",
            title="Heavy rain in your area",
            description="Avoid crossing flooded streets and stay somewhere safe.",
            area_name="Monterrey",
            severity=Severity.high,
            area="SRID=4326;MULTIPOLYGON(((-100.35 25.60,-100.23 25.60,-100.23 25.72,-100.35 25.72,-100.35 25.60)))",
            starts_at=now - timedelta(minutes=20),
            expires_at=now + timedelta(hours=6),
        ))
        s.add_all([
            CommunityReport(user_id=family[0][0].id, type=CommunityReportType.flood,
                            details="Flooded street", location=point(25.6552, -100.2895),
                            expires_at=now + timedelta(hours=3)),
            CommunityReport(user_id=family[1][0].id, type=CommunityReportType.traffic_light,
                            details="Traffic light out at the intersection", location=point(25.6516, -100.2870),
                            expires_at=now + timedelta(hours=2)),
        ])

        s.add_all([
            Lesson(title="CPR", duration_seconds=272, position=1,
                   description="How to give chest compressions to an adult who isn't breathing while the ambulance arrives."),
            Lesson(title="Choking", duration_seconds=190, position=2,
                   description="What to do if someone can't breathe, cough or speak."),
            Lesson(title="Bleeding", duration_seconds=165, position=3,
                   description="How to control bleeding with direct pressure."),
            Lesson(title="Burns", duration_seconds=185, position=4,
                   description="First steps for minor and severe burns."),
        ])

    print("Seed complete")


if __name__ == "__main__":
    main()
