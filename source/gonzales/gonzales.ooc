
use microhttpd
import microhttpd/microhttpd

Server: class {

    daemon: MHDDaemon
    requestHandler: Func (Request) -> Int

    init: func {
        requestHandler = func (r: Request) -> Int {
            r respond(404, "Not found")
        }
    }

    listen: func (port: Int, =requestHandler) {
        daemon = MHDDaemon start(MHDFlag selectInternally, port, null, null, _handleRequest&, this, MHDOption end)
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
        uploadDataSize: SizeT,
        conCls: Pointer) -> Int {

        data: String = null
        if (uploadData) {
            data = String new(uploadData, uploadDataSize)
        }

        req := Request new(
            connection,
            url toString(),
            method toString(),
            _version toString(),
            data)
        rh := this requestHandler
        rh(req)
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

    respond: func (status: Int, content: String) -> Int {
        response := MHDResponse createFromBuffer(content size, content toCString(), MHDResponseMemoryMode persistent)
        ret := connection queueResponse(status, response)
        response destroy()
        ret
    }

}
