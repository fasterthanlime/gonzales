
use microhttpd
import microhttpd/microhttpd

import structs/[ArrayList, HashMap]
import threading/Thread
import os/Time

Server: class {

    daemon: MHDDaemon
    pending := ArrayList<Request> new()
    queue := ArrayList<Request> new()
    mutex := Mutex new()

    init: func (port: Int) {
        flags := MHDFlag selectInternally | MHDFlag suspendResume | MHDFlag debug
        daemon = MHDDaemon start(
            flags, port,
            null, null,
            _handleRequest&, this,
            MHDOption end)
    }

    stop: func {
        daemon stop()
    }

    _handleRequest: func (
        connection: MHDConnection,
        url: CString,
        method: CString,
        _version: CString,
        uploadData: CString,
        uploadDataSize: SizeT*,
        conCls: Pointer*) -> Int {

        req: Request
        if (conCls@ == null) {
            // first time, only the headers are valid, create request but do not respond
            req = Request new(
                connection,
                url toString(),
                method toString(),
                _version toString())

            mutex with(||
                pending add(req)
            )
            conCls@ = req
            return MHDRetCode yes
        } else {
            req = conCls@ as Request
        }

        match (req method) {
            case "GET" =>
                // all good!
            case "POST" =>
                pp := req postProcessor()
                if (uploadDataSize@) {
                    pp process(uploadData, uploadDataSize@)
                    uploadDataSize@ = 0
                    return MHDRetCode yes
                } else {
                    // done parsing
                    pp destroy()
                }
        }

        mutex with(||
            queue add(req)
            pending remove(req)
        )

        // FIXME: this is terrible, but I don't know what else to do.
        // high-performance http server writers, forgive me, for herefore I sin
        processed := false
        while (!processed) {
            Time sleepMilli(5)
            mutex with(||
                processed = !(queue contains?(req))
            )
        }

        MHDRetCode yes
    }

    poll: func -> Request {
        req: Request = null
        mutex with(||
            if (!queue empty?()) {
                req = queue removeAt(0)
            }
        )
        req
    }

}

Request: class {

    connection: MHDConnection
    url: String
    method: String
    _version: String

    postData := HashMap<String, String> new()
    _postProcessor: MHDPostProcessor

    init: func (=connection, =url, =method, =_version) {
        // muffin
    }

    respond: func (status: Int, content: String) {
        response := MHDResponse createFromBuffer(
            content size, content toCString(), MHDResponseMemoryMode mustCopy)
        ret := connection queueResponse(status, response)
        response destroy()
        connection resume()
    }

    postProcessor: func () -> MHDPostProcessor {
        if (!_postProcessor) {
            _postProcessor = MHDPostProcessor new(connection,
                256, This postIterate&, this)
        }
        _postProcessor
    }

    postIterate: func (kind: Int, key: CString,
        fileName: CString, contentType: CString,
        transferEncoding: CString, data: CString,
        offset: UInt64, size: SizeT) -> Int {

        // Sometimes the callback gets called once more in the end
        // with a zero size and a valid key, so that's fun.
        if (size > 0) {
            // TODO: so much, and yet so little time
            value := String new((data as Char*) + offset, size)
            postData put(key toString(), value)
        }

        MHDRetCode yes
    }

}
