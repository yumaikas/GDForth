: ^ ( name -- instance ) class-db &instance( nom ) ;
: bye ( -- ) self &quit() ;

: eof? ( code -- bool ) 18 eq? ;
: OK 0 ;
: ok? OK eq? ;
: NODE_ELEMENT 1 ;
: XML-ELEMENT? ( xml -- t/f ) &get_node_type() NODE_ELEMENT eq? ;
: NODE_ELEMENT_END 2 ;
: XML-ELEMENT-END? ( xml -- t/f ) &get_node_type() NODE_ELEMENT_END eq? ;


: get-xml-parser ( -- ) :XMLParser ^ u< u@ &open( :./gd_docs/@GDScript.xml ) throw u> ;
:: empty-node? ( xml -- empty ) u< u@ XML-ELEMENT? u> &is_empty() and ;

: TABS ( n -- ) 2 * range [ drop SP print-raw ] each ;
: [1+] [ 1+ ] ; : [1-] [ 1- ] ;

:: main ( -- ) get-xml-parser =xml 0 =depth
    [ *xml &read() ok? =cont
        *cont [ 
            *xml XML-ELEMENT? [ [1+] %depth *depth TABS { *xml &get_node_name() :began }: print ] if
            *xml empty-node? [ [1-] %depth *depth TABS { *xml &get_node_name() :empty }: print ] if
            *xml XML-ELEMENT-END? [ [1-] %depth *depth TABS { *xml &get_node_name() :ended }: print ] if
        ] if 
    *cont ] while
;
main bye 

