;;; alchemist-help.el --- Interaction with an Elixir IEx process

;; Copyright © 2014 Samuel Tonini

;; Author: Samuel Tonini <tonini.samuel@gmail.com

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;;  Interaction with an Elixir IEx process

;;; Code:

(require 'comint)

(defvar alchemist-iex-program-name "iex")

(defvar alchemist-iex-buffer nil
  "The buffer in which the Elixir IEx process is running.")

(define-derived-mode alchemist-iex-mode comint-mode "Alchemist-IEx"
  "Major mode for interacting with an Elixir IEx process."
  (set (make-local-variable 'comint-prompt-regexp)
       "^iex(\\([0-9]+\\|[a-zA-Z_@]+\\))> ")
  (set (make-local-variable 'comint-input-autoexpand) nil))

(defun alchemist-iex-string-to-strings (string)
  "Split the STRING into a list of strings."
  (let ((i (string-match "[\"]" string)))
    (if (null i) (split-string string)  ; no quoting:  easy
      (append (unless (eq i 0) (split-string (substring string 0 i)))
              (let ((rfs (read-from-string string i)))
                (cons (car rfs)
                      (inferior-haskell-string-to-strings
                       (substring string (cdr rfs)))))))))

(defun alchemist-iex-command (arg)
  (alchemist-iex-string-to-strings
   (if (null arg) alchemist-iex-program-name
     (read-string "Command to run Elixir IEx: " alchemist-iex-program-name))))

(defvar alchemist-iex-buffer nil
  "The buffer in which the inferior process is running.")

(defun alchemist-iex-start-process (command)
  "Start an IEX process.
With universal prefix \\[universal-argument], prompts for a COMMAND,
otherwise uses `alchemist-iex-program-name'.
It runs the hook `alchemist-iex-hook' after starting the process and
setting up the alchemist IEx buffer."
  (interactive (list (alchemist-iex-command current-prefix-arg)))
  (setq alchemist-iex-buffer
        (apply 'make-comint "Alchemist-IEx" (car command) nil (cdr command)))
  (with-current-buffer alchemist-iex-buffer
    (alchemist-iex-mode)
    (run-hooks 'alchemist-iex-hook)))

(defun alchemist-iex-process (&optional arg)
  (or (if (buffer-live-p alchemist-iex-buffer)
          (get-buffer-process alchemist-iex-buffer))
      (progn
        (let ((current-prefix-arg arg))
          (call-interactively 'alchemist-iex-start-process))
        (alchemist-iex-process arg))))

;;;###autoload
(defalias 'run-elixir 'alchemist-iex-run)
;;;###autoload
(defun alchemist-iex-run (&optional arg)
  "Show the iex buffer. Start the process if needed."
  (interactive "P")
  (let ((proc (alchemist-iex-process arg)))
    (pop-to-buffer (process-buffer proc))))

(defun alchemist-iex--remove-newlines (string)
  (replace-regexp-in-string "\n" " " string))

(defun alchemist-iex-send-current-line ()
  "Sends the current line to the inferior IEx process."
  (interactive)
  (let ((str (thing-at-point 'line)))
    (alchemist-iex--send-command (alchemist-iex-process) str)))

(defun alchemist-iex-send-region (beg end)
  "Sends the marked region to the inferior IEx process."
  (interactive (list (point) (mark)))
  (unless (and beg end)
    (error "The mark is not set now, so there is no region"))
  (let* ((region (buffer-substring-no-properties beg end)))
    (alchemist-iex--send-command (alchemist-iex-process) region)))

(defun alchemist-iex--send-command (proc str)
  (let ((str (concat (alchemist-iex--remove-newlines str) "\n")))
    (with-current-buffer (process-buffer proc)
      (goto-char (process-mark proc))
      (insert-before-markers str)
      (move-marker comint-last-input-end (point))
      (comint-send-string proc str))))

(provide 'alchemist-iex)

;;; alchemist-iex.el ends here