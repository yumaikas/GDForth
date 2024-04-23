: bye ( -- ) self &quit() ;
: gather-http-resp ( result response_code headers body -- dict ) dict u<
    u@ :body put 
    u@ :headers put
    u@ :response_code put
    u@ :result put
    u> ;
    
: req ( -- req ) self .http_request ;
: http-get ( path -- resp ) req &request( nom ) throw req ~request_completed gather-http-resp ;
: body-str ( resp -- body-str ) :body get &get_string_from_utf8() ;
:: str-in? ( str test -- ) swap &find( nom ) -1 gt? ;

:: gdlink ( a -- b ) =l { :https://docs.godotengine.org/en/3.5/classes/ *l }ES: ;
: index-body ( -- body ) :index.html gdlink http-get body-str ;
:: get-link ( line -- link ) =l
    *l &find( :"class ) 1+ =from
    *l &find_last( DQ ) *from - =len
    *l &substr( *from *len )
;

: u@class-link? ( str -- ? ) u@ :toctree-l1 str-in? u@ :class_ str-in? and ;
    

 { index-body &split( NL ) [ u< u@class-link? [ u> get-link ] [ u> drop ] if-else ] each }
 0 nth gdlink http-get body-str print bye
