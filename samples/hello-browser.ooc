
use gonzales
import gonzales/gonzales

import os/Time

srv := Server new(4141)

served := 0
while (served < 1) {
    req := srv poll()
    if (req) {
        match (req method) {
            case "GET" =>
                req respond(200, "<html><body>Hello, browser!</body></html>")
            case "POST" =>
                res := "Here's your POST data: \n"
                req postData each(|key, value|
                    res += "#{key} = #{value}\n"
                )
                req respond(200, res)
        }
        served += 1
    }
    Time sleepMilli(16)
}

srv stop()

