*----------------------------------------------------------------------*
*       CLASS ZCL_LOGGER DEFINITION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
class zcl_logger definition
  public
  create private
  global friends zcl_logger_factory .

  public section.
*"* public components of class ZCL_LOGGER
*"* do not include other source files here!!!
    type-pools abap .

    interfaces zif_logger.
    aliases: add for zif_logger~add,
             a for zif_logger~a,
             e for zif_logger~e,
             w for zif_logger~w,
             i for zif_logger~i,
             s for zif_logger~s,
             has_errors for zif_logger~has_errors,
             has_warnings for zif_logger~has_warnings,
             is_empty for zif_logger~is_empty,
             length for zif_logger~length,
             save for zif_logger~save,
             export_to_table for zif_logger~export_to_table,
             fullscreen for zif_logger~fullscreen,
             popup for zif_logger~popup,
             handle for zif_logger~handle,
             db_number for zif_logger~db_number,
             header for zif_logger~header.

    "! Starts a new log.
    "! For backwards compatibility only! Use ZCL_LOGGER_FACTORY instead.
    class-methods new
      importing
        !object         type csequence optional
        !subobject      type csequence optional
        !desc           type csequence optional
        !context        type simple optional
        !auto_save      type abap_bool optional
        !second_db_conn type abap_bool default abap_true
      returning
        value(r_log)    type ref to zcl_logger .

    "! Reopens an already existing log.
    "! For backwards compatibility only! Use ZCL_LOGGER_FACTORY instead.
    class-methods open
      importing
        !object                   type csequence
        !subobject                type csequence
        !desc                     type csequence optional
        !create_if_does_not_exist type abap_bool default abap_false
        !auto_save                type abap_bool optional
      returning
        value(r_log)              type ref to zcl_logger .

  protected section.
*"* protected components of class ZCL_LOGGER
*"* do not include other source files here!!!
  private section.
* Local type for hrpad_message as it is not available in an ABAP Development System
    types: begin of hrpad_message_field_list_alike,
             scrrprfd type scrrprfd.
    types: end of hrpad_message_field_list_alike.

    types: begin of hrpad_message_alike,
             cause(32)    type c,                          "original: hrpad_message_cause
             detail_level type ballevel.
            include type symsg .
    types: field_list type standard table of hrpad_message_field_list_alike
           with non-unique key scrrprfd.
    types: end of hrpad_message_alike.

*"* private components of class ZCL_LOGGER
*"* do not include other source files here!!!
    data  sec_connection           type abap_bool .
    data  sec_connect_commit       type abap_bool .
    data  settings                 type ref to zif_logger_settings.

    methods:
      "! Safety limit for previous exception drill down
      drill_down_into_exception
        importing
          exception                      type ref to cx_root
          type                           type symsgty optional
          importance                     type balprobcl optional
        returning
          value(rt_exception_data_table) type tty_exception_data,

      get_message_handles
        importing
          msgtype                   type symsgty optional
        returning
          value(rt_message_handles) type bal_t_msgh ,

      add_structure
        importing
          structure_to_log type any.

    methods get_structure_fields
      importing
        !data_structure type ref to cl_abap_structdescr
      changing
        !structure_fields type cl_abap_tabledescr=>component_table.
endclass.



class zcl_logger implementation.


  method drill_down_into_exception.
    data: i                  type i value 2,
          previous_exception type ref to cx_root,
          exceptions         type tty_exception.

    field-symbols <ex> like line of exceptions.
    append initial line to exceptions assigning <ex>.
    <ex>-level = 1.
    <ex>-exception = exception.

    previous_exception = exception.

    while i <= settings->get_max_exception_drill_down( ).
      if previous_exception->previous is not bound.
        exit.
      endif.

      previous_exception ?= previous_exception->previous.

      append initial line to exceptions assigning <ex>.
      <ex>-level = i.
      <ex>-exception = previous_exception.
      i = i + 1.
    endwhile.

    field-symbols <ret> like line of rt_exception_data_table.
    sort exceptions by level descending.                   "Display the deepest exception first
    loop at exceptions assigning <ex>.
      append initial line to rt_exception_data_table assigning <ret>.
      <ret>-exception = <ex>-exception.
      <ret>-msgty     = type.
      <ret>-probclass = importance.
    endloop.
  endmethod.


  method get_message_handles.

    data: log_handle type bal_t_logh,
          filter     type bal_s_mfil.

    field-symbols <f> like line of filter-msgty.

    insert handle into table log_handle.

    if msgtype is not initial.
      append initial line to filter-msgty assigning <f>.
      <f>-sign   = 'I'.
      <f>-option = 'EQ'.
      <f>-low    = msgtype.
    endif.

    call function 'BAL_GLB_SEARCH_MSG'
      exporting
        i_t_log_handle = log_handle
        i_s_msg_filter = filter
      importing
        e_t_msg_handle = rt_message_handles
      exceptions
        msg_not_found  = 0.

  endmethod.


  method new.

    if auto_save is supplied.
      r_log ?= zcl_logger_factory=>create_log(
        object = object
        subobject = subobject
        desc = desc
        context = context
        settings = zcl_logger_factory=>create_settings(
          )->set_usage_of_secondary_db_conn( second_db_conn
          )->set_autosave( auto_save )
      ).
    else.
      r_log ?= zcl_logger_factory=>create_log(
        object = object
        subobject = subobject
        desc = desc
        context = context
        settings = zcl_logger_factory=>create_settings(
          )->set_usage_of_secondary_db_conn( second_db_conn )
      ).
    endif.

  endmethod.


  method open.

    if auto_save is supplied.
      r_log ?= zcl_logger_factory=>open_log(
        object = object
        subobject = subobject
        desc = desc
        create_if_does_not_exist = create_if_does_not_exist
        settings = zcl_logger_factory=>create_settings(
          )->set_autosave( auto_save )
      ).
    else.
      r_log ?= zcl_logger_factory=>open_log(
        object = object
        subobject = subobject
        desc = desc
        create_if_does_not_exist = create_if_does_not_exist
      ).
    endif.

  endmethod.


  method a.
    self = add(
      obj_to_log    = obj_to_log
      context       = context
      callback_form = callback_form
      callback_prog = callback_prog
      callback_fm   = callback_fm
      type          = 'A'
      importance    = importance ).
  endmethod.


  method add.

    data: detailed_msg         type bal_s_msg,
          exception_data_table type tty_exception_data,
          free_text_msg        type char200,
          ctx_type             type ref to cl_abap_typedescr,
          ctx_ddic_header      type x030l,
          msg_type             type ref to cl_abap_typedescr,
          msg_table_type       type ref to cl_abap_tabledescr,
          log_numbers          type bal_t_lgnm,
          log_handles          type bal_t_logh,
          log_number           type bal_s_lgnm,
          formatted_context    type bal_s_cont,
          formatted_params     type bal_s_parm.

    field-symbols: <table_of_messages> type any table,
                   <message_line>      type any,
                   <bapiret1_msg>      type bapiret1,
                   <bapi_msg>          type bapiret2,
                   <bapi_coru_msg>     type bapi_coru_return,
                   <bapi_order_msg>    type bapi_order_return,
                   <bdc_msg>           type bdcmsgcoll,
                   <hrpad_msg>         type hrpad_message_alike,
                   <rcomp_msg>         type rcomp,
                   <context_val>       type any.

    if context is not initial.
      assign context to <context_val>.
      formatted_context-value = <context_val>.
      ctx_type                = cl_abap_typedescr=>describe_by_data( context ).

      call method ctx_type->get_ddic_header
        receiving
          p_header     = ctx_ddic_header
        exceptions
          not_found    = 1
          no_ddic_type = 2
          others       = 3.
      if sy-subrc = 0.
        formatted_context-tabname = ctx_ddic_header-tabname.
      endif.
    endif.

    if callback_fm is not initial.
      formatted_params-callback-userexitf = callback_fm.
      formatted_params-callback-userexitp = callback_prog.
      formatted_params-callback-userexitt = 'F'.
    elseif callback_form is not initial.
      formatted_params-callback-userexitf = callback_form.
      formatted_params-callback-userexitp = callback_prog.
      formatted_params-callback-userexitt = ' '.
    endif.

    msg_type = cl_abap_typedescr=>describe_by_data( obj_to_log ).

    if obj_to_log is not supplied.
      detailed_msg-msgty = sy-msgty.
      detailed_msg-msgid = sy-msgid.
      detailed_msg-msgno = sy-msgno.
      detailed_msg-msgv1 = sy-msgv1.
      detailed_msg-msgv2 = sy-msgv2.
      detailed_msg-msgv3 = sy-msgv3.
      detailed_msg-msgv4 = sy-msgv4.
    elseif msg_type->absolute_name = '\TYPE=BAPIRET1'.
      assign obj_to_log to <bapiret1_msg>.
      detailed_msg-msgty = <bapiret1_msg>-type.
      detailed_msg-msgid = <bapiret1_msg>-id.
      detailed_msg-msgno = <bapiret1_msg>-number.
      detailed_msg-msgv1 = <bapiret1_msg>-message_v1.
      detailed_msg-msgv2 = <bapiret1_msg>-message_v2.
      detailed_msg-msgv3 = <bapiret1_msg>-message_v3.
      detailed_msg-msgv4 = <bapiret1_msg>-message_v4.
    elseif msg_type->absolute_name = '\TYPE=BAPIRET2'.
      assign obj_to_log to <bapi_msg>.
      detailed_msg-msgty = <bapi_msg>-type.
      detailed_msg-msgid = <bapi_msg>-id.
      detailed_msg-msgno = <bapi_msg>-number.
      detailed_msg-msgv1 = <bapi_msg>-message_v1.
      detailed_msg-msgv2 = <bapi_msg>-message_v2.
      detailed_msg-msgv3 = <bapi_msg>-message_v3.
      detailed_msg-msgv4 = <bapi_msg>-message_v4.
    elseif msg_type->absolute_name = '\TYPE=BAPI_CORU_RETURN'.
      assign obj_to_log to <bapi_coru_msg>.
      detailed_msg-msgty = <bapi_coru_msg>-type.
      detailed_msg-msgid = <bapi_coru_msg>-id.
      detailed_msg-msgno = <bapi_coru_msg>-number.
      detailed_msg-msgv1 = <bapi_coru_msg>-message_v1.
      detailed_msg-msgv2 = <bapi_coru_msg>-message_v2.
      detailed_msg-msgv3 = <bapi_coru_msg>-message_v3.
      detailed_msg-msgv4 = <bapi_coru_msg>-message_v4.
    elseif msg_type->absolute_name = '\TYPE=BAPI_ORDER_RETURN'.
      assign obj_to_log to <bapi_order_msg>.
      detailed_msg-msgty = <bapi_order_msg>-type.
      detailed_msg-msgid = <bapi_order_msg>-id.
      detailed_msg-msgno = <bapi_order_msg>-number.
      detailed_msg-msgv1 = <bapi_order_msg>-message_v1.
      detailed_msg-msgv2 = <bapi_order_msg>-message_v2.
      detailed_msg-msgv3 = <bapi_order_msg>-message_v3.
      detailed_msg-msgv4 = <bapi_order_msg>-message_v4.
    elseif msg_type->absolute_name = '\TYPE=BDCMSGCOLL'.
      assign obj_to_log to <bdc_msg>.
      detailed_msg-msgty = <bdc_msg>-msgtyp.
      detailed_msg-msgid = <bdc_msg>-msgid.
      detailed_msg-msgno = <bdc_msg>-msgnr.
      detailed_msg-msgv1 = <bdc_msg>-msgv1.
      detailed_msg-msgv2 = <bdc_msg>-msgv2.
      detailed_msg-msgv3 = <bdc_msg>-msgv3.
      detailed_msg-msgv4 = <bdc_msg>-msgv4.
    elseif msg_type->absolute_name = '\TYPE=HRPAD_MESSAGE'.
      assign obj_to_log to <hrpad_msg>.
      detailed_msg-msgty = <hrpad_msg>-msgty.
      detailed_msg-msgid = <hrpad_msg>-msgid.
      detailed_msg-msgno = <hrpad_msg>-msgno.
      detailed_msg-msgv1 = <hrpad_msg>-msgv1.
      detailed_msg-msgv2 = <hrpad_msg>-msgv2.
      detailed_msg-msgv3 = <hrpad_msg>-msgv3.
      detailed_msg-msgv4 = <hrpad_msg>-msgv4.
    elseif msg_type->absolute_name = '\TYPE=RCOMP'.
      assign obj_to_log to <rcomp_msg>.
      detailed_msg-msgty = <rcomp_msg>-msgty.
      detailed_msg-msgid = <rcomp_msg>-msgid.
      detailed_msg-msgno = <rcomp_msg>-msgno.
      detailed_msg-msgv1 = <rcomp_msg>-msgv1.
      detailed_msg-msgv2 = <rcomp_msg>-msgv2.
      detailed_msg-msgv3 = <rcomp_msg>-msgv3.
      detailed_msg-msgv4 = <rcomp_msg>-msgv4.
    elseif msg_type->type_kind = cl_abap_typedescr=>typekind_oref.
      exception_data_table = me->drill_down_into_exception(
          exception   = obj_to_log
          type        = type
          importance  = importance
          ).
    elseif msg_type->type_kind = cl_abap_typedescr=>typekind_table.
      assign obj_to_log to <table_of_messages>.
      loop at <table_of_messages> assigning <message_line>.
        add( <message_line> ).
      endloop.
      return.
    elseif msg_type->type_kind = cl_abap_typedescr=>typekind_struct1   "flat structure
        or msg_type->type_kind = cl_abap_typedescr=>typekind_struct2.  "deep structure (already when string is used)
      free_text_msg = msg_type->absolute_name.
      shift free_text_msg left deleting leading '\TYPE='.
      concatenate '--- Structure' free_text_msg into free_text_msg separated by space.
      add( obj_to_log    = free_text_msg
           context       = context
           callback_form = callback_form
           callback_prog = callback_prog
           callback_fm   = callback_fm
           type          = type
           importance    = importance ).
      clear free_text_msg.
      add_structure( obj_to_log ).
    else.
      free_text_msg = obj_to_log.
    endif.

    if free_text_msg is not initial.
      call function 'BAL_LOG_MSG_ADD_FREE_TEXT'
        exporting
          i_log_handle = me->handle
          i_msgty      = type
          i_probclass  = importance
          i_text       = free_text_msg
          i_s_context  = formatted_context
          i_s_params   = formatted_params.
    elseif exception_data_table is not initial.
      field-symbols <exception_data> like line of exception_data_table.
      loop at exception_data_table assigning <exception_data>.
        call function 'BAL_LOG_EXCEPTION_ADD'
          exporting
            i_log_handle = me->handle
            i_s_exc      = <exception_data>.
      endloop.
    elseif detailed_msg is not initial.
      detailed_msg-context   = formatted_context.
      detailed_msg-params    = formatted_params.
      detailed_msg-probclass = importance.
      call function 'BAL_LOG_MSG_ADD'
        exporting
          i_log_handle = me->handle
          i_s_msg      = detailed_msg.
    endif.

    if me->settings->get_autosave( ) = abap_true.
      append me->handle to log_handles.
      call function 'BAL_DB_SAVE'
        exporting
          i_t_log_handle       = log_handles
          i_2th_connection     = me->sec_connection
          i_2th_connect_commit = me->sec_connect_commit
        importing
          e_new_lognumbers     = log_numbers.
      if me->db_number is initial.
        read table log_numbers index 1 into log_number.
        me->db_number = log_number-lognumber.
      endif.
    endif.

    self = me.
  endmethod.


  method add_structure.
    data: structure_descriptor type ref to cl_abap_structdescr,
          components type cl_abap_structdescr=>component_table,
          component like line of components.
    field-symbols: <component> type any.

    structure_descriptor ?= cl_abap_structdescr=>describe_by_data( structure_to_log ).
    get_structure_fields( exporting data_structure   = structure_descriptor
                          changing  structure_fields = components  ).
    loop at components into component.
      check component-type->kind = cl_abap_typedescr=>kind_elem.
      assign component sy-tabix of structure structure_to_log to <component>.
      if sy-subrc = 0.
        add( obj_to_log = |-{ to_lower( component-name ) } = { <component> }|
             importance = '4' ).
      endif.
    endloop.
  endmethod.


  method e.
    self = add(
      obj_to_log    = obj_to_log
      context       = context
      callback_form = callback_form
      callback_prog = callback_prog
      callback_fm   = callback_fm
      type          = 'E'
      importance    = importance ).
  endmethod.


  method export_to_table.
    data: message_handles type bal_t_msgh,
          message         type bal_s_msg,
          bapiret2        type bapiret2.

    field-symbols <msg_handle> type balmsghndl.

    message_handles = get_message_handles( ).

    loop at message_handles assigning <msg_handle>.
      call function 'BAL_LOG_MSG_READ'
        exporting
          i_s_msg_handle = <msg_handle>
        importing
          e_s_msg        = message
        exceptions
          others         = 3.
      if sy-subrc is initial.
        message id message-msgid
                type message-msgty
                number message-msgno
                into bapiret2-message
                with message-msgv1 message-msgv2 message-msgv3 message-msgv4.

        bapiret2-type       = message-msgty.
        bapiret2-id         = message-msgid.
        bapiret2-number     = message-msgno.
        bapiret2-log_no     = <msg_handle>-log_handle.     "last 2 chars missing!!
        bapiret2-log_msg_no = <msg_handle>-msgnumber.
        bapiret2-message_v1 = message-msgv1.
        bapiret2-message_v2 = message-msgv2.
        bapiret2-message_v3 = message-msgv3.
        bapiret2-message_v4 = message-msgv4.
        bapiret2-system     = sy-sysid.
        append bapiret2 to rt_bapiret.
      endif.
    endloop.

  endmethod.


  method fullscreen.

    data:
      profile        type bal_s_prof,
      lt_log_handles type bal_t_logh.

    append me->handle to lt_log_handles.

    call function 'BAL_DSP_PROFILE_SINGLE_LOG_GET'
      importing
        e_s_display_profile = profile.

    call function 'BAL_DSP_LOG_DISPLAY'
      exporting
        i_s_display_profile = profile
        i_t_log_handle      = lt_log_handles.

  endmethod.


  method has_errors.

    rv_yes = boolc( lines( get_message_handles( msgtype = 'E' ) ) > 0 ).

  endmethod.


  method has_warnings.

    rv_yes = boolc( lines( get_message_handles( msgtype = 'W' ) ) > 0 ).

  endmethod.


  method i.
    self = add(
      obj_to_log    = obj_to_log
      context       = context
      callback_form = callback_form
      callback_prog = callback_prog
      callback_fm   = callback_fm
      type          = 'I'
      importance    = importance ).
  endmethod.


  method is_empty.

    rv_yes = boolc( length( ) = 0 ).

  endmethod.


  method length.

    rv_length = lines( get_message_handles( ) ).

  endmethod.


  method popup.
* See SBAL_DEMO_04_POPUP for ideas

    data:
      profile        type bal_s_prof,
      lt_log_handles type bal_t_logh.

    append me->handle to lt_log_handles.

    call function 'BAL_DSP_PROFILE_POPUP_GET'
      importing
        e_s_display_profile = profile.

    call function 'BAL_DSP_LOG_DISPLAY'
      exporting
        i_s_display_profile = profile
        i_t_log_handle      = lt_log_handles.

  endmethod.


  method s.
    self = add(
      obj_to_log    = obj_to_log
      context       = context
      callback_form = callback_form
      callback_prog = callback_prog
      callback_fm   = callback_fm
      type          = 'S'
      importance    = importance ).
  endmethod.


  method save.

    data:
      log_handles type bal_t_logh,
      log_numbers type bal_t_lgnm,
      log_number  type bal_s_lgnm.

    check me->settings->get_autosave( ) = abap_false.

    append me->handle to log_handles.
    call function 'BAL_DB_SAVE'
      exporting
        i_t_log_handle       = log_handles
        i_2th_connection     = me->sec_connection
        i_2th_connect_commit = me->sec_connect_commit
      importing
        e_new_lognumbers     = log_numbers.
    if me->db_number is initial.
      read table log_numbers index 1 into log_number.
      me->db_number = log_number-lognumber.
    endif.

  endmethod.


  method w.
    self = add(
      obj_to_log    = obj_to_log
      context       = context
      callback_form = callback_form
      callback_prog = callback_prog
      callback_fm   = callback_fm
      type          = 'W'
      importance    = importance ).
  endmethod.

  
  method get_structure_fields.
    data structure_components type cl_abap_structdescr=>component_table.
    data structure_component like line of structure_components.
    data substructure type ref to cl_abap_structdescr.

    structure_components = data_structure->get_components( ).
    loop at structure_components into structure_component.
      if structure_component-as_include = 'X'.
        substructure ?= structure_component-type.
        get_structure_fields( exporting data_structure   = substructure
                              changing  structure_fields = structure_fields ).
      else.
        append structure_component to structure_fields.
      endif.
    endloop.
  endmethod.
endclass.
