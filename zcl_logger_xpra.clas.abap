class zcl_logger_xpra definition
  public
  inheriting from zcl_logger
  create protected

  global friends zcl_logger_factory .

  public section.
    methods constructor .

  protected section.
    methods save_log redefinition.

  private section.

endclass.


class zcl_logger_xpra implementation.

  method constructor.
*   Create an application log (memory only) to store messages until they are saved to the database
    super->constructor( ).
    call function 'BAL_LOG_CREATE'
      exporting
        i_s_log      = zif_logger~header
      importing
        e_log_handle = zif_logger~handle.
    call function 'BAL_LOG_HDR_READ'
      exporting
        i_log_handle = zif_logger~handle
      importing
        e_s_log      = zif_logger~header.
  endmethod.


  method save_log.
    data log_messages type standard table of sprot_u with default key.
    data message_handles type bal_t_msgh.
    data message type bal_s_msg.
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
        append map_from_application_log_messg( message ) to log_messages.
      endif.
    endloop.
    call function 'TR_APPEND_LOG'
      tables
        xmsg           = log_messages
      exceptions
        file_not_found = 1
        wrong_call     = 2.
    if sy-subrc = 0.
      call function 'BAL_LOG_MSG_DELETE_ALL'
        exporting
          i_log_handle  = zif_logger~handle
        exceptions
          log_not_found = 0.
    endif.
  endmethod.

endclass.
