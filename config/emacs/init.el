;;; -*- lexical-binding: t -*-

(require 'org)

;; Tangle a config .org into tangle/ the moment it is saved, so `ss sync' never
;; ships a stale .el.  `async-program' is spelled out because a Dock-launched
;; Emacs has no /opt/homebrew/bin in PATH.
(use-package org-auto-tangle
  :demand t
  :init (setq async-program "/opt/homebrew/bin/emacs")
  :hook (org-mode . org-auto-tangle-mode))

;; `laf' is loaded from early-init.el, before the first frame exists.
(load-config "editor")
(load-config "writing")
(load-config "programming")
(load-config "addons" t)
(load-config "llm" t)
