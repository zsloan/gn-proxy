#lang racket

(require db
         redis
         json
         threading
         racket/match
         web-server/http
         web-server/servlet-dispatch
         web-server/web-server
         "db.rkt"
         "groups.rkt"
         "privileges.rkt"
         "resource.rkt")


;;;; Endpoints

(define redis-conn (connect-redis))

;; example endpoint
(define (age req)
  (define binds (request-bindings/raw req))
  (define message
    (match (list (bindings-assq #"name" binds)
                 (bindings-assq #"age" binds))
      [(list #f #f)
       "Anonymous is unknown years old."]

      [(list #f (binding:form _ age))
       (format "Anonymous is ~a years old." age)]

      [(list (binding:form _ name) #f)
       (format "~a is unknown years old." name)]
      [(list (binding:form _ name)
             (binding:form _ age))
       (format "~a is ~a years old." name age)]))
  (response/output
   (lambda (out)
     (displayln message out))))

;; Query available actions for a resource, for a given user
(define (query-available req)
  (define binds (request-bindings/raw req))
  (define (masked-actions actions)
    (for/hash ([(k v) (in-hash actions)])
      (values k (map car v))))
  (define message
    (match (list (bindings-assq #"resource" binds)
                 (bindings-assq #"user" binds))
      [(list #f #f)
       "provide resource and user id"]
      [(list (binding:form _ res-id)
             (binding:form _ user-id))
       (let* ((res (get-resource redis-conn res-id))
              (mask (get-mask-for-user
                     redis-conn
                     res
                     (string->number
                      (bytes->string/utf-8 user-id)))))
         (~> (apply-mask (resource-actions res) mask)
             (masked-actions)
             (jsexpr->bytes)))]))
  (response/output
   (lambda (out)
     (displayln message out))))

(define (run-action req)
  (define binds (request-bindings/raw req))
  (define message
    (match (list (bindings-assq #"resource" binds)
                 (bindings-assq #"user" binds)
                 (bindings-assq #"action" binds))
      [(list #f #f #f)
       "provide resource id, user id, and action to perform"]
      [(list (binding:form _ res-id)
             (binding:form _ user-id)
             (binding:form _ action))
       (let* ((res (get-resource redis-conn res-id))
              (mask (get-mask-for-user
                     redis-conn
                     res
                     (string->number
                      (bytes->string/utf-8 user-id)))))
         (jsexpr->bytes mask))]))
  (response/output
   (lambda (out)
     (displayln message out))))

;; Attempt to run an action on a resource as a given user
;; TODO

;; Run the server (will be moved to another module later)
(define stop
  (serve
   #:dispatch (dispatch/servlet query-available)
   #:listen-ip "127.0.0.1"
   #:port 8080))

(with-handlers ([exn:break? (lambda (e)
                              (stop))])
  (sync/enable-break never-evt))