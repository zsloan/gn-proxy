#lang racket

(require racket/set)


; The `privilege` is one of the two fundamental building blocks, and
; is a group of users together with an `action`, which is a function
; that can be called by the privileged users.
(struct privilege (group action))

(define (mk-privilege g f)
  (privilege g f))

(define (perform-action priv u args)
  (if (has-user? (privilege-group priv) u)
      (privilege-action args)
      'no-access))

; Groups and users are the second, for now, a user is simply an ID
(struct user (id))

(define (same-user? a b)
  (equal? (user-id a) (user-id b)))

;A `group` is a collection of users of different levels, including a
; non-empty set of admin users
(struct group (admins members))

(define (mk-group owner)
  (group (set owner) (set empty)))

(define (has-user? g u)
  (or (set-member? (group-admins g) u)
      (set-member? (group-members g) u)))

(define (add-member g u)
  (if (has-user? g u)
      g
      (struct-copy group
                   g
                   [members (set-add (group-members g) u)])))

(define (del-member g u)
  (struct-copy group
               g
               [admins (set-remove (group-admins g) u)]
               [members (set-remove (group-members g) u)]))

(define (make-admin g m)
  (if (has-user? g m)
      (struct-copy group
                   g
                   [admins (set-add (group-admins g) m)]
                   [members (set-remove (group-members g) m)])
      g))


; Resources are named collections of privileges with an owner, and the
; contents that are used by the privilege actions (e.g. URL, dataset
; ID, etc.)
(struct resource (name owner content privileges))

(define (try-action res user action args)
  (define priv (hash-ref (resource-privileges res)
                         action
                         (lambda () (raise 'action-not-found))))
  ;; priv)
  (define grp (privilege-group priv))
  ;; grp)
  (if (has-user? grp user)
      (apply (privilege-action priv) args)
      (error 'no-access)))

; Return a list of the privileges, and their respective user groups,
; for a resource
;; (define (resource-list-privileges res)
;;   (

(struct dataset (desc data) #:mutable)

(struct collection (metadata datasets) #:mutable)

;; (define (mk-data data)

;; (define (view-data data)
;;   (lambda () (data)))

(define (mk-dataset name data desc owner)
  (define group (mk-group owner))
  (define privs (make-hash))
  (define dset (dataset desc data))
  (hash-set! privs 'view-data
             (mk-privilege group
                           (lambda () (dataset-data dset))))
  (hash-set! privs 'edit-data
             (mk-privilege group
                           (lambda (f)
                             (set-dataset-data! dset (f (dataset-data dset))))))
  (hash-set! privs 'view-desc
             (mk-privilege group
                           'undefined))
  (hash-set! privs 'edit-desc
             (mk-privilege group
                           'undefined))
  (resource name owner dset privs))

;; (define (mk-resource n o ps)
;;   (resource n o ps))