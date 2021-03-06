// Copyright 2017 Foursquare Labs Inc. All Rights Reserved.

package io.fsq.rogue.adapter.callback.twitter

import com.twitter.util.{Future, Promise, Return, Throw}
import io.fsq.rogue.adapter.callback.{MongoCallback, MongoCallbackFactory}
import scala.util.{Failure, Success, Try}


class TwitterFutureMongoCallback[T] extends MongoCallback[Future, T] {

  private val promise = new Promise[T]

  override def result: Future[T] = promise

  override protected def processResult(value: T): Unit = {
    promise.setValue(value)
  }

  override protected def processThrowable(throwable: Throwable): Unit = {
    promise.setException(throwable)
  }
}

class TwitterFutureMongoCallbackFactory extends MongoCallbackFactory[Future] {

  override def newCallback[T]: TwitterFutureMongoCallback[T] = {
    new TwitterFutureMongoCallback[T]
  }

  override def transformResult[T, U](result: Future[T], f: Try[T] => Future[U]): Future[U] = {
    result.transform(_ match {
      case Return(value) => f(Success(value))
      case Throw(throwable) => f(Failure(throwable))
    })
  }

  override def wrapResult[T](value: => T): Future[T] = Future(value)

  override def wrapException[T](e: Throwable): Future[T] = Future.exception(e)
}
