// Scala WebSocket Client
import akka.actor.ActorSystem
import akka.http.scaladsl.Http
import akka.http.scaladsl.model.ws._
import akka.http.scaladsl.model.StatusCodes
import akka.stream.scaladsl._
import akka.{Done, NotUsed}
import scala.concurrent.{Future, Promise}
import scala.util.{Failure, Success}
import scala.concurrent.duration._

class WebSocketClient(url: String)(implicit system: ActorSystem) {
  import system.dispatcher

  private val incoming: Sink[Message, Future[Done]] =
    Sink.foreach[Message] {
      case message: TextMessage.Strict =>
        println(s"Received: ${message.text}")
        onMessage(message.text)
      case message: TextMessage.Streamed =>
        message.textStream.runFold("")(_ + _).foreach { text =>
          println(s"Received: $text")
          onMessage(text)
        }
      case message: BinaryMessage.Strict =>
        println(s"Received binary data: ${message.data.length} bytes")
        onBinaryMessage(message.data.toArray)
      case message: BinaryMessage.Streamed =>
        message.dataStream.runFold(akka.util.ByteString.empty)(_ ++ _).foreach { data =>
          println(s"Received binary data: ${data.length} bytes")
          onBinaryMessage(data.toArray)
        }
    }

  private val outgoing: Source[Message, NotUsed] = {
    Source.maybe[Message]
  }

  def connect(): Future[Done] = {
    val webSocketFlow = Http().webSocketClientFlow(WebSocketRequest(url))
    
    val (upgradeResponse, closed) =
      outgoing
        .viaMat(webSocketFlow)(Keep.right)
        .toMat(incoming)(Keep.both)
        .run()

    val connected = upgradeResponse.flatMap { upgrade =>
      if (upgrade.response.status == StatusCodes.SwitchingProtocols) {
        println("Connected to WebSocket server")
        Future.successful(Done)
      } else {
        throw new RuntimeException(s"Connection failed: ${upgrade.response.status}")
      }
    }

    connected.onComplete {
      case Success(_) => onOpen()
      case Failure(ex) => onError(ex)
    }

    closed.onComplete {
      case Success(_) => 
        println("Connection closed")
        onClose()
      case Failure(ex) => 
        println(s"Connection failed: ${ex.getMessage}")
        onError(ex)
    }

    connected
  }

  def send(message: String): Unit = {
    // In a real implementation, you'd need to manage the outgoing source
    // This is a simplified example
    println(s"Sent: $message")
  }

  def close(): Unit = {
    // Close the connection
    system.terminate()
  }

  // Override these methods in your implementation
  protected def onOpen(): Unit = {}
  protected def onMessage(message: String): Unit = {}
  protected def onBinaryMessage(data: Array[Byte]): Unit = {}
  protected def onClose(): Unit = {}
  protected def onError(error: Throwable): Unit = {}
}

// Usage example
object WebSocketExample extends App {
  implicit val system: ActorSystem = ActorSystem("websocket-client")
  import system.dispatcher

  val client = new WebSocketClient("ws://localhost:8080")

  client.connect().onComplete {
    case Success(_) =>
      // Send a message after connection
      Thread.sleep(1000)
      client.send("Hello from Scala!")
      
      // Close after 5 seconds
      Thread.sleep(5000)
      client.close()
      
    case Failure(ex) =>
      println(s"Failed to connect: ${ex.getMessage}")
      system.terminate()
  }
}

// Add to build.sbt:
/*
libraryDependencies ++= Seq(
  "com.typesafe.akka" %% "akka-actor" % "2.6.20",
  "com.typesafe.akka" %% "akka-stream" % "2.6.20",
  "com.typesafe.akka" %% "akka-http" % "10.2.10"
)
*/