
use gonzales
import gonzales/gonzales

import os/Time

srv := Server new(4141)

served := 0
while (served < 1) {
    req := srv poll()
    if (req) {
        req respond(200, "<html><body>Hello, browser!</body></html>")
        served += 1
    }
    Time sleepMilli(16)
}

srv stop()

