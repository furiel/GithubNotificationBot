(import time)
(import json)
(import urllib.parse)
(import http.client urllib.parse)
(import base64)
(import sys)

(defn format-single-notification [notification githubconn]

  (setv latest-comment-url
        (.
          (urllib.parse.urlparse
            (get notification "subject" "latest_comment_url")) path))

  (setv latest-comment
        (json.loads
          (.decode
            (.request githubconn latest-comment-url) "utf-8")))

  (urllib.parse.quote
    (.format "title: {}\ntype: {}\nuser: {}\nmessage: {}\nlink: {}\n"
             (get notification "subject" "title")
             (get notification "subject" "type")
             (get latest-comment "user" "login")
             (get latest-comment "body")
             (get latest-comment "html_url"))))

(defn parse-notifications [notifications-json githubconn]
  (setv notifications (json.loads (.decode notifications-json "utf-8")))
  (lfor notification notifications (format-single-notification notification githubconn)))

(defclass GithubConnection [object]
  (defn --init-- [self username api-token]
    (setv basic-auth-secret
          (.decode
            (base64.b64encode
              (.encode (.format "{}:{}" username api-token)))))
    (setv self.headers
          {"Content-type" "application/x-www-form-urlencoded"
           "Accept" "application/json"
           "User-Agent" "notification-bot"
           "Authorization" (.format "Basic {}" basic-auth-secret) }))

  (defn connect [self &optional [host "api.github.com"] [context None]]
    (setv self.conn (http.client.HTTPSConnection host :context context))
    self.conn)

  (defn disconnect [self]
    (.close self.conn))

  (defn request [self url &optional [method "GET"]]
    (.request self.conn :method method :url url :headers self.headers)
    (setv response (.getresponse self.conn))

    (if (= 2 (// (int response.status) 100))
        (response.read)
        response.reason)))

(defn fetch-notifications [username api-token]
  (setv githubconn (GithubConnection username api-token))
  (.connect githubconn)

  (setv notifications
        (parse-notifications
          (.request githubconn "/notifications")
          githubconn))

  (.request githubconn "/notifications" :method "PUT")
  (.disconnect githubconn)

  notifications)

(defmacro loop [&rest body]
  `(while 1
     (do ~@body)))

(defmacro periodically [seconds &rest body]
  `(loop
     (do ~@body
         (time.sleep ~seconds))))

(defmain [&rest args]
  (time.sleep 120)

  (setv username (get sys.argv 1)
        api-token (get sys.argv 2))

  (periodically
    300
   (for [notification (fetch-notifications username api-token)]
     (print notification))
   (sys.stdout.flush)))
