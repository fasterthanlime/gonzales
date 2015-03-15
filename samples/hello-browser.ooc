
use gonzales
import gonzales/gonzales

srv := Server new()
srv listen(4141, |req|
    req respond(200, "<html><body>Hello, browser!</body></html>")
)

stdin readLine()

