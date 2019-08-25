;;; Author: Robert Strandh
;;; Copyright (c) 2002, 2003 by 
;;;     Robert Strandh (robert.strandh@gmail.com)

;;; This library is free software; you can redistribute it and/or
;;; modify it under the terms of the GNU Library General Public
;;; License as published by the Free Software Foundation; either
;;; version 2 of the License, or (at your option) any later version.
;;;
;;; This library is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;;; Library General Public License for more details.
;;;
;;; You should have received a copy of the GNU Library General Public
;;; License along with this library; if not, write to the
;;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;;; Boston, MA  02111-1307  USA.

;;; Object sequence library.  The purpose is to divide a sequence of
;;; objects into subsequences such that a cost function is optimized.

(in-package :obseq)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Protocol
;;;

;;; The base class of obseqs.  Client code must mix this class into any
;;; sequence that should be treated.
(defclass obseq () ())

;;; The base class of elements of an obseq.  Client code must mix this
;;; class into any element of the obseq to be treated.
(defclass obseq-elem () ())

;;; Given an obseq and an obseq-elem, find the next element in the
;;; obseq.  Client code must supply two method on this generic
;;; function: one that specializes on the elem argument being nil and
;;; which returns the first element of the obseq, and a second one
;;; that specializes on the obseq element which returns the element
;;; following the one given.  When given the last element of the
;;; sequence, this function must return nil.
(defgeneric obseq-next (obseq elem))

;;; Given an obseq and an obseq-elem, find the previous element in the
;;; obseq.  Client code must supply two method on this generic
;;; function: one that specializes on the elem argument being nil and
;;; which returns the last element of the obseq, and a second one that
;;; specializes on the obseq element which returns the element
;;; preceding the one given.  When given the first element of the
;;; sequence, this function must return nil.
(defgeneric obseq-prev (obseq elem))

;;; Given an obseq and and obseq-elem, this function is called by client
;;; code in order to indicate modifications to the obseq.  Elements
;;; in the obseq after the one given may have been altered, whereas
;;; all the elements preceding the one given are unmodified.  When `nil'
;;; is passed as the element value, even the first element may have
;;;  been damaged.
(defgeneric obseq-first-undamaged-element (obseq elem))

;;; Given an obseq and and obseq-elem, this function is called by client
;;; code in order to indicate modifications to the obseq.  Elements
;;; in the obseq before the one given may have been altered, whereas
;;; all the elements after the one given are unmodified.  When `nil'
;;; is passed as the element value, even the last element may have
;;;  been damaged.
(defgeneric obseq-last-undamaged-element (obseq elem))

;;; There are two types of cost: sequence cost, and total cost.  The
;;; sequence cost reflects the cost of a sequence of individual
;;; elements.  The total cost reflects the cost of a sequence of
;;; sequences.  The way to combine costs is contained in a cost method
;;; which is supplied by client code.

;;; The base class for all cost methods.  A cost method contains
;;; everything that is required to compute individual costs, sequence
;;; costs, and total costs. Client code must mix this class into any
;;; cost method that it defines.  All subclasses of this class should
;;; be immutable.  To change the cost method, client code will have to
;;; create a new one and use (setf obseq-cost-method) (see below) to
;;; modify the cost method of the obseq.
(defclass cost-method () ())

;;; The make-instance function on an object of type obseq accepts the
;;; initarg :cost-method to initialize the cost method of the obseq.

;;; This function is called by client code whenever it wants to modify
;;; the cost function of the obseq.  It is entirely supplied by the
;;; library.  Calling this function will automatically invalidate the
;;; entire obseq so that it will be completely recomputed during the
;;; next call to obseq-solve.
(defgeneric (setf obseq-cost-method) (method obseq))

;;; The base class for the cost of a sequence of elements of an object
;;; sequence. Client code must mix this class into any class used to
;;; reflect sequence cost.
(defclass seq-cost () ())

;;; The base class for the cost of a sequence of object sequences.
;;; Client code moust mix this class into any class used to reflect
;;; total cost.
(defclass total-cost () ())

;;; Given a cost method and two cost designators, compute the combined
;;; cost of the two cost designators.  A cost designator is either a
;;; total cost, a sequence cost, and obseq element or nil.  The cost
;;; designated by total cost or a sequences cost is the designator
;;; itself.  An obseq element designates the sequence cost of a
;;; sequence containing only that element. A designator of nil
;;; designates an empty sequence, or an empty sequence of sequences
;;; according to context.  The library will call this function with
;;; different combinations of arguments:
;;; *  with a total cost and a sequence cost.  In that case the result
;;;    should be the total cost of adding the sequence to the right of
;;;    the sequence of sequences.  Client code must supply a method
;;;    for this argument combination.
;;; *  with a sequence cost and a total cost.  In that case the result
;;;    should be the total cost of adding the sequence to the left of
;;;    the sequence of sequences.  The library supplies a default method
;;;    for this argument combination assuming a symmetric relation by
;;;    making a recursive call with arguments reversed.
;;; *  with a sequence cost and an element.  In that case, the result
;;;    should be the sequence cost of adding the element to the right
;;;    of the sequence.  Client code must supply a method for this
;;;    argument combination.
;;; *  with an element and a sequence cost.  In that case, the result
;;;    should be the sequence cost of adding the element to the left
;;;    of the sequence. The library supplies a default method for this
;;;    argument combination assuming a symmetric relation by making
;;;    a recursive call with arguments reversed.
;;; *  with a sequence cost and nil.  In that case, the result should
;;;    be the total cost of a sequence of the one sequence.  Client code
;;;    must supply a method for this argument combination.
;;; *  with an element and nil.  In that case, the result should be
;;;    the cost of a sequence containing the one element.  Client code
;;;    must supply a method for this argument combination.
;;; *  with a total cost and an element.  The library supplies a method
;;;    that makes a recursive call with the total cost and the sequence
;;;    cost of a sequence containing the single element.  Client code may
;;;    supply a more efficient version.
;;; *  with an element and a total cost.  The library supplies a method
;;;    that makes a recursive call with the sequence cost of a
;;;    sequence containing the single element and the total cost.
;;;    Client code may supply a more efficient version.
(defgeneric combine-cost (cost-method arg1 arg2))

;;; Given a cost method and a sequence cost, this function returns a
;;; true value if and only if the result of adding more elements to
;;; the sequence will be guaranteed to increase the cost.  The libray
;;; supplies a default method on this function that returns nil.
;;; Client code should try to supply a better method on this function
;;; since doing so will considerably decrease the computational
;;; complexity of computing a solution.
(defgeneric seq-cost-cannot-decrease (cost-method seq-cost))

;;; Compare cost1 and cost2 according to the cost method given, and
;;; return true if and only if cost1 is considered smaller than cost2.
;;; The library assumes the ordering to be total so that if neither
;;; (cost-less cost-method cost1 cost2) nor (cost-less cost-method
;;; cost2 cost1) is true, then cost1 and cost2 are the same.  Client
;;; code must define two methods on this function, one to compare two
;;; sequence costs and one to compare two total costs.
(defgeneric cost-less (cost-method cost1 cost2))

;;; This function is called by client code to indicate that it wants the
;;; library to compute a solution to the obseq
(defgeneric obseq-solve (obseq))

;;; This functino is called by client code to obtain a subsequence of
;;; the solution.  Given an element of the obseq, it returns (as two
;;; values) the first and the last element of the subsequence
;;; containing the element given.
(defgeneric obseq-interval (obseq elem))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Implementation
;;;

;;; We use this function to stop expanding the overlap when the
;;; overlap, as a sequence of one sequence, has a higher cost than the
;;; best cut within the overlap, and its cost cannot decrease by
;;; expanding the overlap.  When this is the case, the best cut must
;;; be within the overlap.  Suppose not.  Then the entire overlap must
;;; be contained WITHIN an unbroken subsequence in the best solution.
;;; But that unbroken sequence must then have a higher cost than the
;;; overlap.  Since a lower cost can be found inside the overlap, the
;;; overlap is already big enough.
(defmethod seq-cost-cannot-decrease (cost-method seq-cost)
  (declare (ignore cost-method seq-cost))
  nil)

;;; default methods announced in the protocol

(defmethod combine-cost ((method cost-method) (sc seq-cost) (tc total-cost))
  (combine-cost method tc sc))

(defmethod combine-cost ((method cost-method) (el obseq-elem) (sc seq-cost))
  (combine-cost method sc el))

(defmethod combine-cost ((method cost-method) (tc total-cost) (el obseq-elem))
  (combine-cost method tc (combine-cost method el nil)))

(defmethod combine-cost ((method cost-method) (el obseq-elem) (tc total-cost))
  (combine-cost method (combine-cost method el nil) tc))

;;; default methods for our convenience
(defmethod combine-cost ((method cost-method) (empty (eql nil)) (sc seq-cost))
  (combine-cost method sc empty))

(defmethod combine-cost ((method cost-method) (empty (eql nil)) (tc total-cost))
  (combine-cost method tc empty))

;;; doubly linked list of user-supplied objects
(defclass obseq-elem ()
  ((number-right :initform nil :initarg :number-right :accessor number-right)
   (number-left :initform nil :initarg :number-left :accessor number-left)
   (obseq :initarg :obseq :reader elem-obseq)
   ;; up to and including this object
   (best-tcost-left :initform nil :initarg :best-tcost-left :accessor best-tcost-left)
   (best-cut-left :initform nil :initarg :best-cut-left :accessor best-cut-left)
   ;; up to and including this object
   (best-tcost-right :initform nil :initarg :best-tcost-right :accessor best-tcost-right)
   (best-cut-right :initform nil :initarg :best-cut-right :accessor best-cut-right)))

(defclass obseq ()
  ((method :initarg :cost-method :accessor obseq-cost-method)
   (left-sentinel :initform (make-instance 'obseq-elem :number-left 0))
   (right-sentinel :initform (make-instance 'obseq-elem :number-right 0))
   (head :accessor obseq-head)
   (tail :accessor obseq-tail)
   (solvedp :initform nil :accessor solvedp)
   (best-cut :initform nil :accessor obseq-best-cut)))

(defmethod initialize-instance :after ((obseq obseq) &rest args &key &allow-other-keys)
  (declare (ignore args))
  (with-slots (left-sentinel right-sentinel head tail) obseq
    (setf head left-sentinel
          tail right-sentinel)))

(defun left-sentinel-p (obseq elem)
  (eq elem (slot-value obseq 'left-sentinel)))

(defun right-sentinel-p (obseq elem)
  (eq elem (slot-value obseq 'right-sentinel)))

(defun elem-next (obseq elem)
  (with-slots (left-sentinel right-sentinel) obseq
    (or (obseq-next obseq (if (eq elem left-sentinel) nil elem))
        (slot-value obseq 'right-sentinel))))

(defun elem-prev (obseq elem)
  (with-slots (left-sentinel right-sentinel) obseq
    (or (obseq-prev obseq (if (eq elem right-sentinel) nil elem))
        (slot-value obseq 'left-sentinel))))

;;; we maintain an invariant that stipulates that
;;; 1. elements are numbered in the `number-left' slot sequetially from 0 up-to
;;;    and including the element in the `head' slot.
;;; 2. elements to the right of the one in `head' have a value of `nil'
;;;    in the `number-left' slot.
;;; 3. elements are numbered in the `number-right' slot sequetially from 0 up-to
;;;    and including the element in the `tail' slot.
;;; 4. elements to the left of the one in `tail' have a value of `nil'
;;;    in the `number-left' slot.

(defun rightmost-element-p (obseq elem)
  (null (obseq-next obseq elem)))

(defun may-expand-head-p (obseq)
  (not (rightmost-element-p obseq (slot-value obseq 'head))))

;;; FIXME add condition to prevent unacceptably high complexity
(defun expand-head (obseq)
  (with-slots (head method) obseq
    (let ((new (elem-next obseq head))
          (left head))
      (unless (right-sentinel-p obseq new)
        (setf (number-left new) (1+ (number-left head)) ; invariant
              head new)
        (with-slots (best-tcost-left best-cut-left) head
          (loop with seq-cost = (combine-cost method head nil)
                with tcost = (combine-cost method (best-tcost-left left) seq-cost)
                initially (setf best-tcost-left tcost
                                best-cut-left left)
                until (left-sentinel-p obseq left)
                do (setf seq-cost (combine-cost method left seq-cost)
                         left (elem-prev obseq left)
                         tcost (combine-cost method (best-tcost-left left) seq-cost))
                do (when (cost-less method tcost best-tcost-left)
                     (setf best-tcost-left tcost
                           best-cut-left left))))))))

(defun leftmost-element-p (obseq elem)
  (null (obseq-prev obseq elem)))

(defun may-expand-tail-p (obseq)
  (not (leftmost-element-p obseq (slot-value obseq 'tail))))

;;; FIXME add condition to prevent unacceptably high complexity
(defun expand-tail (obseq)
  (with-slots (tail method) obseq
    (let ((new (elem-prev obseq tail))
          (right tail))
      (setf (number-right new) (1+ (number-right tail)) ; invariant
            tail new)
      (unless (left-sentinel-p obseq new)
        (with-slots (best-tcost-right best-cut-right) tail
          (loop with seq-cost = (combine-cost method tail nil)
                with tcost = (combine-cost method seq-cost (best-tcost-right right))
                initially (setf best-tcost-right tcost
                                best-cut-right right)
                until (right-sentinel-p obseq right)
                do (setf seq-cost (combine-cost method seq-cost right)
                         right (elem-next obseq right)
                         tcost (combine-cost method seq-cost (best-tcost-right right)))
                do (when (cost-less method tcost best-tcost-right)
                     (setf best-tcost-right tcost
                           best-cut-right right))))))))

(defun head-tail-overlap-p (obseq)
  (not (null (number-left (obseq-tail obseq)))))

(defun close-the-gap (obseq)
  (loop until (head-tail-overlap-p obseq)
        do (expand-head obseq)
        until (head-tail-overlap-p obseq)
        do (expand-tail obseq)))

(defun tcost-leftcut (obseq elem)
  (if (leftmost-element-p obseq elem)
      (best-tcost-right elem)
      (cost-max (obseq-cost-method obseq)
                (best-tcost-right elem)
                (best-tcost-left (elem-prev obseq elem)))))

(defun tcost-rightcut (obseq elem)
  (if (rightmost-element-p obseq elem)
      (best-tcost-left elem)
      (cost-max (obseq-cost-method obseq)
                (best-tcost-left elem)
                (best-tcost-right (elem-next obseq elem)))))

(defun create-some-overlap (obseq)
  (with-slots (head tail method) obseq
    (loop with cost-best-cut = (cost-min method
                                         (tcost-leftcut obseq tail)
                                         (tcost-rightcut obseq head))
          with best-cut = (if (cost-less method
                                         (tcost-leftcut obseq tail)
                                         (tcost-rightcut obseq head))
                              (list tail :left)
                              (list head :right))
          with gap-cost = (combine-cost method tail nil)
          until (or (and (leftmost-element-p obseq tail)
                         (rightmost-element-p obseq head))
                    (and (cost-less method cost-best-cut gap-cost)
                         (seq-cost-cannot-decrease method gap-cost)))
          do (when (not (leftmost-element-p obseq tail))
               (expand-tail obseq)
               (when (cost-less method (tcost-leftcut obseq tail) cost-best-cut)
                 (setf cost-best-cut (tcost-leftcut obseq tail)
                       best-cut (list tail :left)))
               (setf gap-cost (combine-cost method tail gap-cost)))
          do (when (not (rightmost-element-p obseq head))
               (expand-head obseq)
               (when (cost-less method (tcost-rightcut obseq head) cost-best-cut)
                 (setf cost-best-cut (tcost-rightcut obseq head)
                       best-cut (list head :right)))
               (setf gap-cost (combine-cost method gap-cost head)))
          finally (progn (setf (obseq-best-cut obseq) best-cut)
                         (return (values (car best-cut) (cadr best-cut) cost-best-cut))))))

(defmethod obseq-solve (obseq)
  (unless (solvedp obseq)
    (close-the-gap obseq)
    (create-some-overlap obseq)))

(defun contract-head (obseq)
  (with-slots (head) obseq
    (assert (not (left-sentinel-p obseq head)))
    (setf (number-left head) nil ; invariant
          head (elem-prev obseq head))))

(defun contract-tail (obseq)
  (with-slots (tail) obseq
    (assert (not (right-sentinel-p obseq tail)))
    (setf (number-right tail) nil ; invariant
          tail (elem-next obseq tail))))

(defmethod obseq-last-undamaged-element (obseq (elem (eql nil)))
  (with-slots (tail) obseq
    (loop until (right-sentinel-p obseq tail)
          do (contract-tail obseq))))

(defmethod obseq-last-undamaged-element (obseq (elem obseq-elem))
  (with-slots (tail) obseq
    (when (and (number-right elem)
               (< (number-right elem)
                  (number-right tail)))
      (loop until (eq tail elem)
            do (contract-tail obseq)))))

(defmethod obseq-last-undamaged-element :after (obseq elem)
  (declare (ignore elem))
  (setf (solvedp obseq) nil))

(defmethod obseq-first-undamaged-element (obseq (elem (eql nil)))
  (with-slots (head) obseq
    (loop until (left-sentinel-p obseq head)
          do (contract-head obseq))))

(defmethod obseq-first-undamaged-element (obseq (elem obseq-elem))
  (with-slots (head) obseq
    (when (and (number-left elem)
               (< (number-left elem)
                  (number-left head)))
      (loop until (eq head elem)
            do (contract-head obseq)))))

(defmethod obseq-first-undamaged-element :after (obseq elem)
  (declare (ignore elem))
  (setf (solvedp obseq) nil))

;;;; ---------------------------------------------------------------------
;;;; Cost functions

;;; Compute the max of two cost objects
(defgeneric cost-max (cost-method cost1 cost2))

(defmethod cost-max (cost-method cost1 cost2)
  (if (cost-less cost-method cost1 cost2) cost2 cost1))

;;; Compute the min of two cost objects
(defgeneric cost-min (cost-method cost1 cost2))

(defmethod cost-min (cost-method cost1 cost2)
  (if (cost-less cost-method cost1 cost2) cost1 cost2))

;;; convenience method allowing us to compare a sequence cost and a
;;; total cost
(defmethod cost-less (cost-method (cost1 total-cost) (cost2 seq-cost))
  (cost-less cost-method cost1 (combine-cost cost-method cost2 nil)))

(defmethod cost-less (cost-method (cost1 seq-cost) (cost2 total-cost))
  (cost-less cost-method (combine-cost cost-method cost1 nil) cost2))

;;; this function can only be used after the obseq is solved
(defun elem<= (elem1 elem2)
  (let ((nl1 (number-left elem1))
        (nl2 (number-left elem2))
        (nr1 (number-right elem1))
        (nr2 (number-right elem2)))
    (cond ((and nl1 nl2) (<= nl1 nl2))
          ((and nr1 nr2) (>= nr1 nr2))
          (t nl1))))

(defun elem< (elem1 elem2)
  (and (elem<= elem1 elem2) (not (eq elem1 elem2))))

(defmethod obseq-interval ((obseq obseq) (elem obseq-elem))
  (destructuring-bind (cut pos) (obseq-best-cut obseq)
    (if (eq pos :left)
        (if (elem<= cut elem)
            (loop with left = cut
                  until (elem< elem (best-cut-right left))
                  do (setf left (best-cut-right left))
                  finally (return (values left (elem-prev obseq (best-cut-right left)))))
            (loop with right = (elem-prev obseq cut)
                  until (elem< (best-cut-left right) elem)
                  do (setf right (best-cut-left right))
                  finally (return (values (elem-next obseq (best-cut-left right)) right))))
        (if (elem<= elem cut)
            (loop with right = cut
                  until (elem< (best-cut-left right) elem)
                  do (setf right (best-cut-left right))
                  finally (return (values (elem-next obseq (best-cut-left right)) right)))
            (loop with left = (elem-next obseq cut)
                  until (elem< elem (best-cut-right left))
                  do (setf left (best-cut-right left))
                  finally (return (values left (elem-prev obseq (best-cut-right left)))))))))

;;; FIXME: implement an :after method on (setf obseq-cost-method) that
;;; invalidates the entire obseq.
