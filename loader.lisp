#|
 This file is a part of trial
 (c) 2017 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package #:org.shirakumo.fraf.trial)

(defgeneric compute-assets (object traversal-cache))
(defgeneric bake (bakable))
(defgeneric baked-p (bakable))
(defgeneric transition (from to))

(defmethod compute-assets :around (object (cache null))
  (compute-assets object (make-hash-table :test 'eq)))

(defmethod compute-assets :around (object (cache hash-table))
  (unless (gethash object cache)
    (setf (gethash object cache) T)
    (call-next-method)))

(defmethod compute-assets ((anything T) cache)
  NIL)

(defmethod compute-assets ((cons cons) cache)
  (nconc (compute-assets (car cons) cache)
         (compute-assets (cdr cons) cache)))

(defmethod compute-assets ((vector vector) cache)
  (unless (typep vector 'string)
    (loop for object across vector
          nconc (compute-assets object cache))))

(defmethod compute-assets ((table hash-table) cache)
  (loop for value being the hash-values of table
        nconc (compute-assets value cache)))

(defmethod compute-assets ((object entity) cache)
  (loop for slot in (c2mop:class-slots (class-of object))
        for name = (c2mop:slot-definition-name slot)
        when (slot-boundp object name)
        nconc (compute-assets (slot-value object name) cache)))

(defmethod compute-assets ((asset asset) cache)
  (nconc (call-next-method) (list asset)))

(defclass bakable ()
  ((baked-p :initform NIL :accessor baked-p)))

(defmethod compute-assets :before ((bakable bakable) cache)
  (bake bakable))

(defmethod bake :around ((bakable bakable))
  (unless (baked-p bakable)
    (call-next-method))
  (setf (baked-p bakable) T))

(defmethod transition ((from null) (to scene))
  (v:info :trial.loader "Transitioning to ~a" to)
  (let ((to-load (compute-assets to NIL)))
    (v:info :trial.loader "Loading ~a assets." (length to-load))
    (v:debug :trial.loader "Loading:~%~a" to-load)
    (mapc #'load to-load)
    to))

(defmethod transition ((from scene) (to null))
  (v:info :trial.loader "Transitioning from ~a" from)
  (let ((to-deallocate (compute-assets to NIL)))
    (v:info :trial.loader "Deallocating ~a assets." (length to-deallocate))
    (v:debug :trial.loader "Deallocating:~%~a" to-deallocate)
    (mapc #'deallocate to-deallocate)
    to))

(defun stable-set-difference-eq (a b)
  (let ((table (make-hash-table :test 'eq)))
    (dolist (item b) (setf (gethash item table) T))
    (remove-if (lambda (item) (gethash item table)) a)))

(defmethod transition ((from scene) (to scene))
  (v:info :trial.loader "Transitioning from ~a to ~a" from to)
  (let* ((from (compute-assets from NIL))
         (to (compute-assets to NIL))
         (to-load (stable-set-difference-eq to from))
         (to-offload (stable-set-difference-eq from to)))
    (v:info :trial.loader "Loading ~a assets." (length to-load))
    (v:debug :trial.loader "Loading:~%~a" to-load)
    (mapc #'load to-load)
    (v:info :trial.loader "Offloading ~a assets." (length to-offload))
    (v:debug :trial.loader "Offloading:~%~a" to-offload)
    (mapc #'offload to-offload)
    to))
