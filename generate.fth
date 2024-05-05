: bye ( -- ) self &quit() suspend ;
: ? ( cond a b -- chosen ) rot [ drop ] [ nip ] if-else ;

: times ( num block -- ) swap range swap each ; ( Doofy impl, replace with something  )

: null? ( val -- t/f ) null eq? ;
: eof? ( code -- bool ) 18 eq? ;
: OK 0 ;
: ok? OK eq? ;
: reversed ( arr -- arr ) .duplicate() dup .invert()! ;

: XML-ELEMENT? ( xml -- t/f ) .get_node_type() @XMLParser.NODE_ELEMENT eq? ;
: XML-ELEMENT-END? ( xml -- t/f ) .get_node_type()> @XMLParser.NODE_ELEMENT_END eq? ;

: xml-named? ( xml name -- t/f ) swap u< u@ XML-ELEMENT? u@ XML-ELEMENT-END? or [ u> &get_node_name()> eq? ] [ drop false ] if-else ;
: ES? ES eq? ;

: null-if ( val cond ) [ drop null ] if ;
: ES?null ( val -- val/null ) dup ES? null-if ;


: @attr ( xml name -- val ) swap .get_named_attribute_value_safe(*) ES?null ; 
: /@name ( xml -- name ) :name @attr ;
: method? ( xml -- t/f ) :method xml-named? ;
: method-end? ( xml -- t/f ) u< u@ :method xml-named? u> XML-ELEMENT-END? and ;
: argument? ( xml -- t/f )  :argument xml-named? ;
: return? ( xml -- t/f )  :return xml-named? ;
: void-return? ( xml -- t/f ) :type @attr :void eq? ;
: default? ( xml -- t/f ) :default @attr null? not ;

: get-xml-parser ( -- ) @XMLParser .new() u< :./gd_docs/@GDScript.xml u@ .open(*) throw u> ;
:: empty-node? ( xml -- empty ) u< u@ XML-ELEMENT? u> &is_empty()> and ;

: TABS ( n -- ) 2 * [ " " print-raw ] times ;
: TABS: ( n -- ) 2 * [ drop " " ] times ;
: [1+] [ 1+ ] ; : [1-] [ 1- ] ;
: has? ( el arr -- t/f ) &find(*)> -1 eq? not ;

: str-kebabify ( str -- str ) u< "_" "-" u> .replace(**) ;

:: main ( -- ) get-xml-parser =xml 0 =depth
    { } =methods
    { } =arg-slidy-methods
    dict =method
    { } =args

    [ *xml &read()> ok? =cont
        *cont [ 
            *xml XML-ELEMENT? [ 
                *xml method? [ *xml :name @attr *method :name put ] if
                *xml argument? *xml default? not and [ *xml :name @attr *args &append(*) ] if
                *xml return? [ *xml void-return? :void :val ? *method :return put ] if
            ] if
            *xml method-end? [ 
                *args *method :args put
                *method *methods .append(*)!
                dict =method
                { } =args
            ] if
        ] if 
    *cont ] while
    "class_name GDForthStdLib extends Reference" print
    "" print
    { :yield :printraw :printt :prints :print_debug :print :preload :get_stack :assert } =remove
    {
        *methods [ dup =m :name get *remove has? not [ *m ] if ] each 
    } =methods
    ( TODO: Emit a loader method )

    "func load(VM):" print
     *methods [ =m *m :name get =m-name
        { "    VM._comp_map['" *m-name str-kebabify "'] = funcref(self, 'gdf_" *m-name "')" }: print
     ] each 
     "" print

    true =first?
    *methods [ =m 
        *m :args get =args 
        *m :name get =name
        *m :return get :val eq? =method-returns
        { 
         "func gdf_" *m :name get "(VM):\n"
         *args reversed [ =a 2 TABS: "var " *a " = VM._pop()\n" ] each
         2 TABS:
             *method-returns [ "var ret = " ] if
             *name "(" *args ", " &join(*)> ")\n" 
         *method-returns [ 2 TABS: "VM._push(ret)\n" ] if
         2 TABS: "VM.IP += 1" 
        }: print
        "" print
        false =first?
    ] each 
   ;
"stdlib.gd" [ main ] with-file
bye 

