(import time)
(import json)
(import urllib.parse)
(import http.client urllib.parse)
(import base64)
(import sys)

(defn format-notifications [notifications-json]
  (setv notifications (json.loads (.decode notifications-json "utf-8")))
  (for [notification notifications]
    (print
      (urllib.parse.quote
        (.format "title: {}\ntype: {}\nurl: {}"
                 (get notification "subject" "title")
                 (get notification "subject" "type")
                 (get notification "subject" "url"))))))

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
        (response.reason))))

(defn fetch-notifications [username api-token]
  (setv githubconn (GithubConnection username api-token))
  (.connect githubconn)
  (format-notifications (.request githubconn "/notifications"))
  (.request githubconn "/notifications" :method "PUT")
  (.disconnect githubconn))

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
   (fetch-notifications username api-token)
   (sys.stdout.flush)))
