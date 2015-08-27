; program purpose: 
;   inject watching websocket code into html page being served, refresh served page on 
;   file-system change (or other synchronizable event, in this case just file-system)
;
;   built to make it easier to get a fast workflow with luxe primarily
;
;   requires: rfc6455 - websocket library

#lang racket

(require net/rfc6455)
(require racket/cmdline)
(require web-server/servlet
         web-server/servlet-env)

; command line arguments config
(define index-file (make-parameter "index.html"))
(define watched-directory (make-parameter "."))

; listener
(define (listen index directory)
  #t)
