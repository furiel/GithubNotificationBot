import hy
import pytest, os.path, threading, ssl
from githubnotificationfetcher import *
from http.server import HTTPServer, SimpleHTTPRequestHandler, HTTPStatus


# given a pem file ... openssl req -new -x509 -keyout yourpemfile.pem -out yourpemfile.pem -days 365 -nodes
class HttpServerSimulator(object):
    def __init__(self):
        self.httpd =  HTTPServer(('localhost', 5555), HttpRequestHandlerSimulator)
        self.httpd.socket = ssl.wrap_socket (self.httpd.socket, server_side=True,
                                             certfile='testdata/testpemfile.pem')
        self.httpserver = threading.Thread(target=self.httpd.serve_forever)

    def start(self):
        self.httpserver.start()

    def stop(self):
        self.httpd.shutdown()
        self.httpserver.join()


class HttpRequestHandlerSimulator(SimpleHTTPRequestHandler):
    def do_GET(self):
        basename = os.path.basename(self.path)
        testfile = "testdata/{}.json".format(basename)

        if os.path.exists(testfile):
            self.send_response(200)
        else:
            self.send_response(404)
            return

        self.send_header('Content-type','application/json')
        self.end_headers()

        with open(testfile, "r") as f:
            self.wfile.write(bytes(f.read(), "utf8"))

        return


@pytest.fixture
def http_server():
    httpserver =  HttpServerSimulator()
    httpserver.start()
    yield httpserver
    httpserver.stop()


def test_format_notification(http_server):
    githubconn = GithubConnection("testuser", "testpass")
    githubconn.connect("localhost:5555", context=ssl._create_unverified_context())
    notifications = parse_notifications(githubconn.request("/notifications"), githubconn)
    assert "test_title" in notifications[0]
    assert "comment_body" in notifications[0]
    githubconn.disconnect()


def test_freshly_opened_pull_request():
    # Fresh PR-s do not contain latest_comment_url
    notification_string = """
    {
        "subject": {
        "title": "title-of-new-pr",
        "url": "url-of-new-pr",
        "latest_comment_url": null,
        "type": "PullRequest"
        }
    }"""
    single_notification = json.loads(notification_string)
    formatted = format_single_notification(single_notification, None)
    assert formatted == "title: title-of-new-pr\ntype: PullRequest\n"
