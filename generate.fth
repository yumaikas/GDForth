: ^ ( name -- instance ) class-db &instance( nom ) ;
: bye ( -- ) self &quit() ;

: eof? ( code -- bool ) 18 eq? ;
: OK 0 ;
: ok? OK eq? ;
: NODE_ELEMENT 1 ;
: XML-ELEMENT? ( xml -- t/f ) &get_node_type() NODE_ELEMENT eq? ;
: NODE_ELEMENT_END 2 ;
: XML-ELEMENT-END? ( xml -- t/f ) &get_node_type() NODE_ELEMENT_END eq? ;

: xml-named? ( xml -- t/f ) swap &get_node_name() eq? ;
: /@name ( xml -- name ) &get_named_attribute_value( :name ) ;
: /@name ( xml -- name ) &get_named_attribute_value( :name ) ;
: method? ( xml -- t/f ) :method xml-named? ;
: method-end? ( xml -- t/f ) u<  u@ :method xml-named? u> XML-ELEMENT-END? and ;
: argument? ( xml -- t/f )  :argument xml-named? ;
: default? ( xml -- t/f ) &get_named_attribute_value_safe( :default ) ES eq? not ;

: if- ( cond block -- ) swap [ do-block true ] [ drop false ] if-else  ;
: -elif- ( conda condb block -- taken? ) u< and [ u> do-block true ] [ u> drop false ] if-else ;
: -elif ( conda condb block -- taken? ) u< and [ u> do-block ] [ u> drop ] if-else ;
: -else ( taken? block -- ) swap [ do-block ] [ drop ] if-else ;

: get-xml-parser ( -- ) :XMLParser ^ u< u@ &open( :./gd_docs/@GDScript.xml ) throw u> ;
:: empty-node? ( xml -- empty ) u< u@ XML-ELEMENT? u> &is_empty() and ;

: TABS ( n -- ) 2 * range [ drop SP print-raw ] each ;
: [1+] [ 1+ ] ; : [1-] [ 1- ] ;

:: main ( -- ) get-xml-parser =xml 0 =depth
    { } =methods
    { } =arg-slidy-methods
    dict =method
    { } =args

    [ *xml &read() ok? =cont
        *cont [ 
            *xml XML-ELEMENT? [ 
                *xml method? [ *xml /@name *method :name put ] if
                *xml argument? *xml default? not and [ *args &append( *xml /@name ) ] if
            ] if- 
            *xml method-end? [ 
                *args *method :args put
                *methods &append( *method )
                dict =method
            ] -elif
        ] if 
    *cont ] while
    *methods print
;
main bye 

