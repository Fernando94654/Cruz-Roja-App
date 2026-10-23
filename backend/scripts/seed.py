"""Development data mirroring the SwiftUI mockup."""

import uuid
from datetime import date, datetime, timedelta, timezone

from argon2 import PasswordHasher
from sqlalchemy import text

from app.crypto import encrypt_list
from app.db import SessionLocal
from app.models import (
    Circle,
    CircleInvitation,
    CircleMember,
    CommunityReport,
    EmergencyContact,
    MedicalProfile,
    OfficialAlert,
    User,
    UserLocation,
    WellbeingCheck,
)
from app.models.alerts import CommunityReportType, Severity
from app.models.circles import CircleRole, WellbeingStatus
from app.models.medical import BloodType


# Same id as APIConfig.demoUserID in the iOS app
DEMO_USER_ID = uuid.UUID("00000000-0000-4000-8000-000000000001")


def point(lat: float, lng: float) -> str:
    return f"SRID=4326;POINT({lng} {lat})"


def main():
    now = datetime.now(timezone.utc)
    password = PasswordHasher().hash("demo1234")

    with SessionLocal.begin() as s:
        s.execute(text("TRUNCATE users, official_alerts CASCADE"))

        me = User(id=DEMO_USER_ID, email="user@example.com", password_hash=password, name="María López",
                  phone="8110000001")
        # (user, how María calls them, shares location, lat, lng)
        family = [
            (User(email="mom@example.com", password_hash=password, name="Ana López", phone="8112345678"),
             "Hija", True, 25.6600, -100.3000),
            (User(email="dad@example.com", password_hash=password, name="Jorge López", phone="8110000003"),
             "Pareja", True, 25.6450, -100.2800),
            (User(email="sister@example.com", password_hash=password, name="Lucía López", phone="8110000004"),
             "Hermana", False, 25.6700, -100.3100),
        ]
        carmen = User(email="carmen@example.com", password_hash=password, name="Carmen Ruiz", phone="8110000005")
        s.add_all([me, carmen, *(f[0] for f in family)])
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

        circle = Circle(name="Familia", created_by=me.id)
        carmens = Circle(name="Familia", created_by=carmen.id)
        s.add_all([circle, carmens])
        s.flush()
        s.add(CircleMember(circle_id=circle.id, user_id=me.id, role=CircleRole.admin))
        s.add(CircleMember(circle_id=carmens.id, user_id=carmen.id, role=CircleRole.admin))
        s.add(UserLocation(user_id=me.id, location=point(25.6516, -100.2895)))
        for u, relationship, shares, lat, lng in family:
            s.add(CircleMember(circle_id=circle.id, user_id=u.id, relationship=relationship, shares_location=shares))
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
        s.flush()

        # Family screen: Ana needs help, Jorge is fine, Lucía hasn't answered and Jorge asked María
        ana, jorge, lucia = (f[0] for f in family)
        s.add_all([
            WellbeingCheck(user_id=ana.id, requested_by=me.id, status=WellbeingStatus.need_help,
                           created_at=now - timedelta(minutes=10), answered_at=now - timedelta(minutes=2)),
            WellbeingCheck(user_id=jorge.id, requested_by=me.id, status=WellbeingStatus.ok,
                           created_at=now - timedelta(hours=2), answered_at=now - timedelta(hours=1)),
            WellbeingCheck(user_id=lucia.id, requested_by=me.id, status=WellbeingStatus.no_response,
                           created_at=now - timedelta(minutes=30)),
            WellbeingCheck(user_id=me.id, requested_by=jorge.id, status=WellbeingStatus.no_response,
                           created_at=now - timedelta(minutes=5)),
            CircleInvitation(circle_id=circle.id, invited_by=me.id, name="Pedro López", contact="8110000006",
                             relationship="Nieto", token="seed-pedro", created_at=now - timedelta(hours=2),
                             expires_at=now + timedelta(days=7)),
            CircleInvitation(circle_id=carmens.id, invited_by=carmen.id, name="María López", contact="8110000001",
                             relationship="Otro", token="seed-carmen", created_at=now - timedelta(days=1),
                             expires_at=now + timedelta(days=6)),
        ])

        s.add_all([
            CommunityReport(user_id=family[0][0].id, type=CommunityReportType.flood,
                            details="Flooded street", location=point(25.6552, -100.2895),
                            expires_at=now + timedelta(hours=3)),
            CommunityReport(user_id=family[1][0].id, type=CommunityReportType.traffic_light,
                            details="Traffic light out at the intersection", location=point(25.6516, -100.2870),
                            expires_at=now + timedelta(hours=2)),
        ])

    print("Seed complete")


if __name__ == "__main__":
    main()
