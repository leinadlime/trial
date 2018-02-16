#|
 This file is a part of trial
 (c) 2017 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package #:org.shirakumo.fraf.trial)

(defclass image (asset texture)
  ())

(defmethod load ((image image))
  (unwind-protect
       (let ((input (coerce-asset-input (input image))))
         (multiple-value-bind (bits width height)
             (cl-soil:load-image (unlist input))
           (setf (pixel-data image) bits)
           (setf (width image) width)
           (setf (height image) height))
         (when (listp input)
           (setf (pixel-data image) (list (pixel-data image)))
           (dolist (input (rest input))
             (multiple-value-bind (bits width height)
                 (cl-soil:load-image input)
               (push bits (pixel-data image))
               (assert (= width (width image)))
               (assert (= height (height image)))))
           (setf (pixel-data image) (nreverse (pixel-data image))))
         (allocate image))
    (mapcar #'cffi:foreign-free (enlist (pixel-data image)))))

(defmethod resize ((image image) width height)
  (error "Resizing is not implemented for images."))
