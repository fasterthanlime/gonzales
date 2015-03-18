
use microhttpd
import microhttpd/microhttpd

import structs/[ArrayList, HashMap]
import threading/Thread
import os/Time

GC_stack_base: cover from struct GC_stack_base {}

GC_allow_register_threads: extern func
GC_get_stack_base: extern func(GC_stack_base*) -> Int
GC_register_my_thread: extern func(GC_stack_base*)
GC_unregister_my_thread: extern func()

// too soon for Boehm's doc's taste, but oh well
GC_allow_register_threads()

Server: class {

    daemon: MHDDaemon
    pending := ArrayList<Request> new()
    queue := ArrayList<Request> new()
    mutex := Mutex new()

    init: func (port: Int) {
        flags := MHDFlag threadPerConnection | MHDFlag debug
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

        // register thread first
        base: GC_stack_base
        GC_get_stack_base(base&)
        GC_register_my_thread(base&)

        doQueue := false

        req: Request
        if (conCls@ == null) {
            // first time, only the headers are valid

            // create request but do not respond
            req = Request new(
                connection,
                url toString(),
                method toString(),
                _version toString())

            mutex with(||
                pending add(req)
            )
            conCls@ = req
        } else {
            req = conCls@ as Request

            match (req method) {
                case "GET" =>
                    // all good!
                    doQueue = true
                case "POST" =>
                    if (uploadDataSize@) {
                        pp := req postProcessor()
                        pp process(uploadData, uploadDataSize@)
                        uploadDataSize@ = 0
                        GC_unregister_my_thread()
                        return MHDRetCode yes
                    } else {
                        // done parsing
                        req destroyPostProcessor()
                        doQueue = true
                    }
            }
        }

        if (doQueue) {
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
        }

        GC_unregister_my_thread()
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
    }

    postProcessor: func () -> MHDPostProcessor {
        if (!_postProcessor) {
            _postProcessor = MHDPostProcessor new(connection,
                256, This postIterate&, this)
        }
        _postProcessor
    }

    destroyPostProcessor: func {
        if (_postProcessor) {
            _postProcessor destroy()
            _postProcessor = null
        }
    }

    postIterate: func (kind: Int, _key: CString,
        fileName: CString, contentType: CString,
        transferEncoding: CString, data: Char*,
        offset: UInt64, size: SizeT) -> Int {

        // TODO: so much, and yet so little time
        key := _key toString()

        value := String new(data, size) clone()

        if (postData contains?(key)) {
            prevValue := postData get(key)
            postData put(key, prevValue + value)
        } else {
            postData put(key, value)
        }

        MHDRetCode yes
    }

}
