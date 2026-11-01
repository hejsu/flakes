;; -*- lexical-binding: t -*-

;; `user-emacs-directory' already defaults to ~/.config/emacs.  Do not derive it
;; from `load-file-name': that resolves symlinks, so under nix it would point
;; into the read-only store and `tangle/' could not be written.

;; Startup: keep GC and the file-name handlers out of the way until the session
;; is up.  `gcmh' takes over from `emacs-startup-hook'.
(setq gc-cons-percentage 1.0)
(setq gc-cons-threshold most-positive-fixnum)
(setq read-process-output-max (* 64 1024))
(setq frame-inhibit-implied-resize t)

;; Saved under different names: `let' on these special variables would restore
;; them as soon as the `let' exits, which is not what we want.
(let ((saved-handlers file-name-handler-alist)
      (saved-suffixes load-suffixes)
      (saved-rep-suffixes load-file-rep-suffixes))
  (setq file-name-handler-alist nil
        load-suffixes '(".elc" ".el")
        load-file-rep-suffixes '(""))
  (add-hook 'emacs-startup-hook
            (lambda ()
              (setq file-name-handler-alist saved-handlers
                    load-suffixes saved-suffixes
                    load-file-rep-suffixes saved-rep-suffixes))
            101))

;; Emacs 31 can cache directory mtimes instead of re-reading them on every
;; `load-path' lookup.
(when (fboundp 'load-path-filter-cache-directory-files)
  (setq load-path-filter-function #'load-path-filter-cache-directory-files))

;; Keep `M-x customize' output out of init.el, and actually read it back.
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(load custom-file 'noerror)

;; XDG layout: config lives in ~/.config/emacs, packages in
;; ~/.local/share/emacs, byte-code in ~/.cache/emacs.  Both must be set
;; before straight bootstraps, because straight reads them at load time.
;; `xdg.el' honours $XDG_DATA_HOME / $XDG_CACHE_HOME and falls back to the
;; standard paths when those variables are absent (GUI launch through
;; launchd has no shell environment).
(require 'xdg)
(setq straight-base-dir (expand-file-name "emacs" (xdg-data-home)))
(setq native-comp-eln-load-path
      (cons (expand-file-name "emacs/eln-cache/" (xdg-cache-home))
            (cdr native-comp-eln-load-path)))

;; org-roam's files reference each other's functions without requiring them, so
;; native compilation reports a pile of "not known to be defined" warnings on
;; every start.  They are forward references, not errors -- the functions all
;; exist at runtime and the .eln builds fine.
(setq native-comp-async-report-warnings-errors 'silent)

;; Define configuration loader helper
(defun load-config (config-name &optional force-tangle)
  "Tangle cfg/CONFIG-NAME.org to tangle/CONFIG-NAME.el and load it."
  (let* ((source (expand-file-name (format "%s.org" config-name)
                                   (expand-file-name "cfg" user-emacs-directory)))
	 (tangle-dir (expand-file-name "tangle" user-emacs-directory))
	 (target (expand-file-name (format "%s.el" config-name) tangle-dir)))
    (when (file-exists-p source)
      (make-directory tangle-dir t)
      (when (or force-tangle
                (not (file-exists-p target))
                (file-newer-than-file-p source target))
        (require 'org)
        (require 'ob)
        ;; The destination comes from the file's own :tangle header; a
        ;; file-level property outranks the target argument, so passing one
        ;; here would be silently ignored.
        (org-babel-tangle-file source))
      (load-file target))))

;; Package revisions, deployed next to the rest of the config like nvim's
;; lazy-lock.json.  Written by `straight-freeze-versions' and committed: straight
;; checks out these commits when it clones a package on a fresh machine.  Being
;; a store symlink it is read-only except while swapped, so freezing is a
;; swap-time operation -- the same session in which you would be editing the
;; config to add the package anyway.  Must be set before straight bootstraps.
(setq straight-profiles
      '((nil . "~/.config/emacs/straight-versions.el")))

;; Setup straight as package manager
(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name "straight/repos/straight.el/bootstrap.el" straight-base-dir))
      (bootstrap-version 5))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/raxod502/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

;; Straight configs
(setq straight-vc-git-default-clone-depth 1)

;; Let `use-package' install through straight, so every package form is a
;; single declaration instead of straight-use-package + require + hooks.
(setq straight-use-package-by-default t)

;; Org ships with Emacs 31 (9.8.7 in lisp/org).  Tell straight to skip it
;; entirely so packages that depend on Org (org-roam, org-ql, …) use the
;; bundled copy instead of cloning emacs-straight/org-mode.  Without this,
;; straight builds a 10.0-pre tree, then compiles it against the already
;; loaded built-in Org, producing a broken mixture and the
;; "Org version mismatch" warning on every start.
(add-to-list 'straight-built-in-pseudo-packages 'org)

;; Same for transient: Emacs 31 ships 0.13.3, magit asks for >= 0.13 and every
;; transient-* symbol it references exists there, so straight should not pull a
;; second copy in just to satisfy magit's dependency list.
(add-to-list 'straight-built-in-pseudo-packages 'transient)

;; `laf' goes first and only here: it sets the default frame font and loads the
;; theme, both of which have to be in place before the first GUI frame exists.
;; Everything else loads from init.el.
(load-config "laf")
