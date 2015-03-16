
use microhttpd
import microhttpd/microhttpd

import structs/ArrayList
import threading/Thread
import os/Time

Server: class {

    daemon: MHDDaemon
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

        dummy: Int
        if (dummy& != conCls@) {
            // The first time only the headers are valid, do not respond in the first round...
            conCls@ = dummy&
            return MHDRetCode yes
        }

        data: String = null
        if (uploadDataSize@ > 0) {
            data = String new(uploadData, uploadDataSize@)
        }

        req := Request new(
            connection,
            url toString(),
            method toString(),
            _version toString(),
            data)

        mutex with(||
            queue add(req)
        )

        // FIXME:this is terrible, but apart from having an external FD thing,
        // I don't know what else to do.
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
    uploadData: String


    init: func (=connection, =url, =method, =_version, =uploadData) {
        // muffin
    }

    respond: func (status: Int, content: String) {
        response := MHDResponse createFromBuffer(
            content size, content toCString(), MHDResponseMemoryMode mustCopy)
        ret := connection queueResponse(status, response)
        response destroy()
        connection resume()
    }

}
