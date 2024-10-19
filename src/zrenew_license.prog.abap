*&---------------------------------------------------------------------*
*& Report zrenew_license
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zrenew_license.


TYPES: BEGIN OF ty_json,
         _type      TYPE string,
         _name      TYPE string,
         _email     TYPE string,
         _hwkey     TYPE string,
         _host_i_d  TYPE string,
         _host_name TYPE string,
       END OF ty_json.

DATA: lv_url         TYPE string VALUE 'https://go.support.sap.com/minisap/odata/bkey/minisap/LicenseKey',
      lv_xcsrf_token TYPE string,
      lv_response    TYPE string,
      lo_http_client TYPE REF TO if_http_client,
      lt_table       TYPE likey_file_contents,
      lt_xml_table   TYPE STANDARD TABLE OF smum_xmltb,
      lt_return      TYPE STANDARD TABLE OF bapiret2,
      lv_input       TYPE xstring,
      lt_error       TYPE likey_error_tab,
      lv_hwkey       TYPE custkey_t,
      lv_systemno    TYPE likey_system_no.


PARAMETERS:
  pa_name  TYPE string,
  pa_email TYPE string.


CALL METHOD cl_http_client=>create_by_url
  EXPORTING
    url    = lv_url
  IMPORTING
    client = lo_http_client.

lo_http_client->propertytype_accept_cookie = if_http_client=>co_enabled.


lo_http_client->request->set_header_field( name = 'x-csrf-token' value = 'fetch' ).

CALL METHOD lo_http_client->send
  EXCEPTIONS
    http_communication_failure = 1
    http_invalid_state         = 2
    OTHERS                     = 3.

CALL METHOD lo_http_client->receive
  EXCEPTIONS
    http_communication_failure = 1
    http_invalid_state         = 2
    OTHERS                     = 3.

lv_xcsrf_token = lo_http_client->response->get_header_field( 'x-csrf-token' ).

CALL FUNCTION 'SLIC_LOCAL_HWKEY'
  IMPORTING
    hwkey           = lv_hwkey
  EXCEPTIONS
    parameter_error = 1
    hardware_error  = 2
    slic_error      = 3
    OTHERS          = 4.
IF sy-subrc <> 0.
  MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
    WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
ENDIF.

CALL FUNCTION 'SLIC_LIKEY_GET_SYSTEM_NO'
  IMPORTING
    systemno             = lv_systemno
*   error_messages       =
  EXCEPTIONS
    no_systemno_assigned = 1
    error                = 2
    OTHERS               = 3.
IF sy-subrc <> 0.
  MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
    WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
ENDIF.

DATA(lv_type) =  COND #( WHEN sy-sysid = 'NPL' THEN '020'
                         WHEN sy-sysid = 'A4H' THEN '025' ).

DATA(ls_json) = VALUE ty_json( _type = lv_type _name = pa_name _email = pa_email _hwkey = lv_hwkey ).

DATA(lv_json_serailized) =  /ui2/cl_json=>serialize(
                              data             = ls_json
                              pretty_name = /ui2/cl_json=>pretty_mode-camel_case
                            ).

lo_http_client->request->set_header_field( name = 'Content-Type' value = 'application/json' ).
lo_http_client->request->set_header_field( name = 'x-csrf-token' value = lv_xcsrf_token ).

lo_http_client->request->set_method( 'POST' ).
lo_http_client->request->set_cdata( lv_json_serailized ).

CALL METHOD lo_http_client->send
  EXCEPTIONS
    http_communication_failure = 1
    http_invalid_state         = 2
    OTHERS                     = 3.

CALL METHOD lo_http_client->receive
  EXCEPTIONS
    http_communication_failure = 1
    http_invalid_state         = 2
    OTHERS                     = 3.

lv_response = lo_http_client->response->get_cdata( ).

CALL METHOD lo_http_client->close.


CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
  EXPORTING
    text   = lv_response
*   mimetype = space
*   encoding =
  IMPORTING
    buffer = lv_input
  EXCEPTIONS
    failed = 1
    OTHERS = 2.
IF sy-subrc <> 0.
  MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
    WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
ENDIF.

CALL FUNCTION 'SMUM_XML_PARSE'
  EXPORTING
    xml_input = lv_input
  TABLES
    xml_table = lt_xml_table
    return    = lt_return.

DATA: lv_row TYPE string.


LOOP AT lt_xml_table REFERENCE INTO DATA(lr_xml_table).

  IF lr_xml_table->cname = 'Licensekey'.

    lv_row = |{ lv_row }{ lr_xml_table->cvalue }|.

  ENDIF.

ENDLOOP.


SPLIT lv_row AT cl_abap_char_utilities=>cr_lf INTO TABLE DATA(lt_rows).

LOOP AT lt_rows REFERENCE INTO DATA(lr_row).

  APPEND lr_row->* TO lt_table.

  IF lr_row->* CS 'SYSTEM-NR'.
    lr_row->* = |SYSTEM-NR={ lv_systemno }|.
  ENDIF.

ENDLOOP.


CALL FUNCTION 'SLIC_LIKEY_INSTALL_LICENSE'
  EXPORTING
    file_lines     = lt_table
  IMPORTING
    error_messages = lt_error
  EXCEPTIONS
    error          = 1
    OTHERS         = 2.
IF sy-subrc <> 0.
  MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
    WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
ENDIF.
