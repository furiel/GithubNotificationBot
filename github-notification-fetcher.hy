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

(defn fetch-notifications [username api-token]
  (setv basic-auth-secret
        (.decode
          (base64.b64encode
                   (.encode (.format "{}:{}" username api-token)))))

  (setv headers
        {"Content-type" "application/x-www-form-urlencoded"
         "Accept" "application/json"
         "User-Agent" "notification-bot"
         "Authorization" (.format "Basic {}" basic-auth-secret) })

  (setv conn (http.client.HTTPSConnection "api.github.com"))
  (.request conn :method "GET" :url "/notifications" :headers headers)

  (setv response (.getresponse conn))

  (if (= 2 (// (int response.status) 100))
      (do
        (format-notifications (response.read))
        (.request conn :method "PUT" :url "/notifications" :headers headers))
      (urllib.parse.quote response.reason))
  (.close conn))

(defmacro loop [&rest body]
  `(while 1
     (do ~@body)))

(defmacro periodically [seconds &rest body]
  `(loop
     (do ~@body
         (time.sleep ~seconds))))

(defn main []
  (time.sleep 120)

  (setv username (get sys.argv 1)
        api-token (get sys.argv 2))

  (periodically
    300
   (fetch-notifications username api-token)
   (sys.stdout.flush)))

(when (= __name__ "__main__")
  (main))
