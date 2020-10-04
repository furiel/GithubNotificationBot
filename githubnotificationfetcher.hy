(import time)
(import json)
(import urllib.parse)
(import http.client urllib.parse)
(import base64)
(import collections)

(defn to-string [x]
  (or (and (isinstance x str) x)
      (and (isinstance x bytes) (.decode x))))

(defn format-single-notification [notification githubconn]

  (setv latest-comment-url
        (.
          (urllib.parse.urlparse
            (get notification "subject" "latest_comment_url")) path))

  (setv latest-comment-response (.request githubconn latest-comment-url))

  (setv latest-comment
        (try
          (json.loads latest-comment-response)
          (except [e Exception]
            (print "Exception occured while parsing latest comment:" latest-comment-url latest-comment-response e :flush True)
            {"user" {"login" "unknown"} "body" "unknown" "html_url" "unknown"})))

  ;; Simple way of throttling: github terminates connection if too many messages are sent at once
  (time.sleep 1)
  (try
    (.format "title: {}\ntype: {}\nuser: {}\nmessage: {}\nlink: {}\n"
               (get notification "subject" "title")
               (get notification "subject" "type")
               (get latest-comment "user" "login")
               (get latest-comment "body")
               (get latest-comment "html_url"))
    (except [e Exception]
      (print "Exception occured" notification latest-comment e :flush True)
      (.format "notification: {} latest-comment: {} exception: {}" notification latest-comment e))))


(defn parse-notifications [notifications-json githubconn]
  (setv notifications (json.loads notifications-json))
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
        (to-string (response.read))
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
