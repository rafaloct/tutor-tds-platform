"""Synthetic Authentik compose drift checks. No network, no credentials."""
import copy
import unittest
from authentik_lab_policy import audit


def sample():
    return {
        "name": "tds_authentik_lab_20261022",
        "volumes": {"database": {"name": "tds_authentik_lab_20261022_database"}},
        "services": {
            "postgresql": {
                "image": "docker.io/library/postgres:16-alpine",
                "volumes": [{"type": "volume", "source": "database", "target": "/var/lib/postgresql/data"}],
            },
            "server": {
                "image": "ghcr.io/goauthentik/server:2026.8.5",
                "ports": [
                    {"host_ip": "127.0.0.1", "published": "19200", "target": 9000},
                    {"host_ip": "127.0.0.1", "published": "19443", "target": 9443},
                ],
            },
            "worker": {"image": "ghcr.io/goauthentik/server:2026.8.5"},
        },
    }


class LabPolicyTests(unittest.TestCase):
    def test_isolated_lab(self):
        self.assertEqual(audit(sample()), [])

    def test_internet_bind_denied(self):
        case = sample()
        case["services"]["server"]["ports"][0]["host_ip"] = "0.0.0.0"
        self.assertIn("public_port", audit(case))

    def test_extra_port_denied(self):
        case = sample()
        case["services"]["server"]["ports"].append({"host_ip": "127.0.0.1", "published": "8080", "target": 8080})
        self.assertIn("unexpected_port", audit(case))

    def test_db_exposure_denied(self):
        case = sample()
        case["services"]["postgresql"]["ports"] = [{"host_ip": "127.0.0.1", "published": "15432", "target": 5432}]
        self.assertIn("nonserver_ports", audit(case))

    def test_docker_socket_denied(self):
        case = sample()
        case["services"]["worker"]["volumes"] = ["/var/run/docker.sock:/var/run/docker.sock"]
        self.assertIn("docker_socket", audit(case))

    def test_host_network_denied(self):
        case = sample()
        case["services"]["worker"]["network_mode"] = "host"
        self.assertIn("elevated_service", audit(case))

    def test_privileged_denied(self):
        case = sample()
        case["services"]["worker"]["privileged"] = True
        self.assertIn("elevated_service", audit(case))

    def test_unpinned_image_denied(self):
        case = sample()
        case["services"]["server"]["image"] = "ghcr.io/goauthentik/server:latest"
        self.assertIn("unpinned_image", audit(case))

    def test_unowned_database_denied(self):
        case = sample()
        case["volumes"]["database"]["external"] = True
        self.assertIn("external_volume", audit(case))

    def test_unexpected_worker_denied(self):
        case = sample()
        case["services"]["production_wp"] = {"image": "wordpress:latest"}
        self.assertEqual(audit(case), ["unexpected_services"])

    def test_project_name_denied(self):
        case = sample()
        case["name"] = "tutor-tds-production"
        self.assertIn("unexpected_project", audit(case))

    def test_missing_https_denied(self):
        case = sample()
        case["services"]["server"]["ports"].pop()
        self.assertIn("missing_ports", audit(case))

    def test_invalid_root_denied(self):
        self.assertEqual(audit([]), ["unexpected_services"])


if __name__ == "__main__":
    unittest.main()
