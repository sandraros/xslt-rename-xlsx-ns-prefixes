*&---------------------------------------------------------------------*
*& Report z_xslt_rename_demo
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT z_xslt_rename_demo.

CLASS lcl_app DEFINITION FINAL.

  PUBLIC SECTION.

    METHODS start_of_selection
      RAISING
        zcx_excel
        cx_static_check.

  PRIVATE SECTION.

    METHODS get_list_of_files
      RETURNING
        VALUE(result) TYPE string_table.

    METHODS gui_upload
      IMPORTING
        file_name     TYPE string
      RETURNING
        VALUE(result) TYPE xstring
      RAISING
        zcx_excel.

    METHODS gui_download
      IMPORTING
        file_name     TYPE string
        file_contents TYPE xstring
      RAISING
        zcx_excel.

ENDCLASS.

CLASS lcl_zip_rename_xmlns_prefixes DEFINITION.
  PUBLIC SECTION.
    METHODS rename
      IMPORTING
        zip_xstring   TYPE xstring
      RETURNING
        VALUE(result) TYPE xstring
      RAISING
        cx_static_check.
ENDCLASS.

CLASS lcl_zip_rename_xmlns_prefixes IMPLEMENTATION.

  METHOD rename.

    DATA(lo_zip) = NEW cl_abap_zip( ).
    lo_zip->load(
      EXPORTING
        zip             = zip_xstring
      EXCEPTIONS
        zip_parse_error = 1
        OTHERS          = 2 ).

    DATA(result_zip) = NEW cl_abap_zip( ).

    LOOP AT lo_zip->files ASSIGNING FIELD-SYMBOL(<ls_zip_file>).

      lo_zip->get(
        EXPORTING
          name                    = <ls_zip_file>-name
        IMPORTING
          content                 = DATA(l_content)
        EXCEPTIONS
          zip_index_error         = 1
          zip_decompression_error = 2
          OTHERS                  = 3 ).

      TRY.

IF 1 = 1
*and <ls_zip_file>-name NP '*hart*'
and <ls_zip_file>-name NP '*rawi*'
*and <ls_zip_file>-name NP '*heet*'
*and <ls_zip_file>-name NP '*workbook*'
*and <ls_zip_file>-name NP '*xl*'
and <ls_zip_file>-name NP '*docprops*'
*and <ls_zip_file>-name NP '*rels*'
*and <ls_zip_file>-name NP '*content_types*'
.
          CALL TRANSFORMATION zxsltrename_xmlns_2 SOURCE XML l_content RESULT XML data(l_content_2).
          l_content = l_content_2.
ENDIF.

        CATCH cx_xslt_runtime_error INTO DATA(error1).
          if error1->textid <> error1->bad_source_context.
            RAISE EXCEPTION error1.
          endif.
      ENDTRY.

          result_zip->add(
            EXPORTING
              name           = <ls_zip_file>-name
              content        = l_content ).

    ENDLOOP.

    result = result_zip->save( ).

  ENDMETHOD.
ENDCLASS.

CLASS zcl_zip_cleanup_for_diff DEFINITION
  CREATE PUBLIC .

  PUBLIC SECTION.

    METHODS cleanup
      IMPORTING
        zip_xstring   TYPE xstring
      RETURNING
        VALUE(result) TYPE xstring
      RAISING
        zcx_excel.

  PRIVATE SECTION.

    TYPES : BEGIN OF ty_zip_structure,
              ref_to_structure TYPE REF TO data,
              ref_to_x         TYPE REF TO data,
              length           TYPE i,
              view             TYPE REF TO cl_abap_view_offlen,
              charset_bit      TYPE i,
              conv_in_utf8     TYPE REF TO cl_abap_conv_in_ce,
              conv_in_ibm437   TYPE REF TO cl_abap_conv_in_ce,
              conv_out_utf8    TYPE REF TO cl_abap_conv_out_ce,
              conv_out_ibm437  TYPE REF TO cl_abap_conv_out_ce,
            END OF ty_zip_structure.

    METHODS write_zip
      IMPORTING
        offset        TYPE i
      CHANGING
        zip_structure TYPE ty_zip_structure
        zip_xstring   TYPE xstring.

    METHODS read_zip
      IMPORTING
        zip_xstring   TYPE xstring
        offset        TYPE i
      CHANGING
        zip_structure TYPE ty_zip_structure.

    METHODS init_structure
      IMPORTING
        length        TYPE i
        charset_bit   TYPE i
        structure     TYPE any
      RETURNING
        VALUE(result) TYPE ty_zip_structure.

ENDCLASS.







CLASS lcl_app IMPLEMENTATION.

  METHOD start_of_selection.
    TYPES: ty_file_range TYPE RANGE OF text1024.
    FIELD-SYMBOLS: <file_range> TYPE ty_file_range.

    ASSIGN ('S_FILTER[]') TO <file_range>.
    ASSIGN ('P_INPUT') TO FIELD-SYMBOL(<folder>).
    ASSIGN ('P_OUTPUT') TO FIELD-SYMBOL(<output_folder>).
    DATA(files) = get_list_of_files( ).
    LOOP AT files ASSIGNING FIELD-SYMBOL(<file>)
        WHERE table_line IN <file_range>.

      DATA(old_xlsx_xstring) = gui_upload( <folder> && <file> ).

      old_xlsx_xstring = NEW lcl_zip_rename_xmlns_prefixes( )->rename( old_xlsx_xstring ).
      gui_download( file_name = <folder> && 'fake_' && <file> file_contents = old_xlsx_xstring ).

      DATA(reader) = NEW zcl_excel_reader_2007( ).
      DATA(excel) = reader->zif_excel_reader~load( old_xlsx_xstring ).
      DATA(writer) = NEW zcl_excel_writer_2007( ).
      DATA(new_xlsx_xstring) = writer->zif_excel_writer~write_file( excel ).
      new_xlsx_xstring = NEW lcl_zip_rename_xmlns_prefixes( )->rename( new_xlsx_xstring ).
      gui_download( file_name = <output_folder> && <file> file_contents = new_xlsx_xstring ).

      DATA(cleaned_up_old_xlsx_xstring) = NEW zcl_zip_cleanup_for_diff( )->cleanup( old_xlsx_xstring ).
      DATA(cleaned_up_new_xlsx_xstring) = NEW zcl_zip_cleanup_for_diff( )->cleanup( new_xlsx_xstring ).
      WRITE : / <file>.
      IF cleaned_up_new_xlsx_xstring = cleaned_up_old_xlsx_xstring.
        WRITE 'OK' COLOR COL_POSITIVE.
      ELSE.
        WRITE 'KO' COLOR COL_NEGATIVE.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD gui_upload.

    DATA(solix_tab) = VALUE solix_tab( ).
    cl_gui_frontend_services=>gui_upload(
      EXPORTING
        filename                = file_name
        filetype                = 'BIN'
      IMPORTING
        filelength              = DATA(file_length)
      CHANGING
        data_tab                = solix_tab
      EXCEPTIONS
        file_open_error         = 1
        file_read_error         = 2
        no_batch                = 3
        gui_refuse_filetransfer = 4
        invalid_type            = 5
        no_authority            = 6
        unknown_error           = 7
        bad_data_format         = 8
        header_not_allowed      = 9
        separator_not_allowed   = 10
        header_too_long         = 11
        unknown_dp_error        = 12
        access_denied           = 13
        dp_out_of_memory        = 14
        disk_full               = 15
        dp_timeout              = 16
        not_supported_by_gui    = 17
        error_no_gui            = 18
        OTHERS                  = 19 ).
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_excel EXPORTING error = |gui_upload error { file_name }|.
    ENDIF.

    result = cl_bcs_convert=>solix_to_xstring( it_solix = solix_tab iv_size = file_length ).

  ENDMETHOD.


  METHOD get_list_of_files.

    APPEND '01_HelloWorld.xlsx' TO result.
    APPEND '02_Styles.xlsx' TO result.
    APPEND '03_iTab.xlsx' TO result.
    APPEND '04_Sheets.xlsx' TO result.
    APPEND '05_Conditional.xlsx' TO result.
    APPEND '06_Formulas.xlsx' TO result.
    APPEND '07_ConditionalAll.xlsx' TO result.
    APPEND '08_Range.xlsx' TO result.
    APPEND '09_DataValidation.xlsx' TO result.
    APPEND '10_iTabFieldCatalog.xlsx' TO result.
    APPEND '12_HideSizeOutlineRowsAndColumns.xlsx' TO result.
    APPEND '13_MergedCells.xlsx' TO result.
    APPEND '14_Alignment.xlsx' TO result.
    APPEND '16_Drawings.xlsx' TO result.
    APPEND '17_SheetProtection.xlsx' TO result.
    APPEND '18_BookProtection.xlsx' TO result.
    APPEND '19_SetActiveSheet.xlsx' TO result.
    APPEND '21_BackgroundColorPicker.xlsx' TO result.
    APPEND '22_itab_fieldcatalog.xlsx' TO result.
    APPEND '23_Sheets_with_and_without_grid_lines.xlsx' TO result.
    APPEND '24_Sheets_with_different_default_date_formats.xlsx' TO result.
    APPEND '27_ConditionalFormatting.xlsx' TO result.
*    APPEND '28_HelloWorld_Sheet2.csv' TO result.
*    APPEND '28_HelloWorld_Sheet1.csv' TO result.
    APPEND '30_CellDataTypes.xlsx' TO result.
    APPEND '31_AutosizeWithDifferentFontSizes.xlsx' TO result.
    APPEND '33_autofilter.xlsx' TO result.
    APPEND '34_Static Styles_Chess.xlsx' TO result.
    APPEND '35_Static_Styles.xlsx' TO result.
    APPEND '36_DefaultStyles.xlsx' TO result.
    APPEND '37- Read template and output.xlsx' TO result.
    APPEND '38_SAP-Icons.xlsx' TO result.
    APPEND '39_Charts.xlsx' TO result.
    APPEND '40_Printsettings.xlsx' TO result.
    APPEND 'ABAP2XLSX Inheritance.xlsx' TO result.
    APPEND 'Comments.xlsx' TO result.
    APPEND 'Image_Header_Footer.xlsx' TO result.
    APPEND '15_01_HelloWorldFromReader.xlsx' TO result.
    APPEND '15_02_StylesFromReader.xlsx' TO result.
    APPEND '15_03_iTabFromReader.xlsx' TO result.
    APPEND '15_04_SheetsFromReader.xlsx' TO result.
    APPEND '15_05_ConditionalFromReader.xlsx' TO result.
    APPEND '15_07_ConditionalAllFromReader.xlsx' TO result.
    APPEND '15_08_RangeFromReader.xlsx' TO result.
    APPEND '15_13_MergedCellsFromReader.xlsx' TO result.
    APPEND '15_24_Sheets_with_different_default_date_formatsFromReader.xlsx' TO result.
    APPEND '15_31_AutosizeWithDifferentFontSizesFromReader.xlsx' TO result.

  ENDMETHOD.


  METHOD gui_download.

    DATA(bin_filesize) = xstrlen( file_contents ).

    DATA(solix_tab) = cl_bcs_convert=>xstring_to_solix( file_contents ).

    cl_gui_frontend_services=>gui_download(
      EXPORTING
        bin_filesize              = bin_filesize
        filename                  = file_name
        filetype                  = 'BIN'
      CHANGING
        data_tab                  = solix_tab
      EXCEPTIONS
        file_write_error          = 1
        no_batch                  = 2
        gui_refuse_filetransfer   = 3
        invalid_type              = 4
        no_authority              = 5
        unknown_error             = 6
        header_not_allowed        = 7
        separator_not_allowed     = 8
        filesize_not_allowed      = 9
        header_too_long           = 10
        dp_error_create           = 11
        dp_error_send             = 12
        dp_error_write            = 13
        unknown_dp_error          = 14
        access_denied             = 15
        dp_out_of_memory          = 16
        disk_full                 = 17
        dp_timeout                = 18
        file_not_found            = 19
        dataprovider_exception    = 20
        control_flush_error       = 21
        not_supported_by_gui      = 22
        error_no_gui              = 23
        OTHERS                    = 24 ).
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_excel EXPORTING error = |gui_download error { file_name }|.
    ENDIF.

  ENDMETHOD.

ENDCLASS.

CLASS zcl_zip_cleanup_for_diff IMPLEMENTATION.

  METHOD cleanup.

    TYPES : BEGIN OF ty_local_file_header,
              local_file_header_signature TYPE x LENGTH 4,  " 04034b50
              version_needed_to_extract   TYPE x LENGTH 2,
              general_purpose_bit_flag    TYPE x LENGTH 2,
              compression_method          TYPE x LENGTH 2,
              last_mod_file_time          TYPE int2,
              last_mod_file_date          TYPE int2,
              crc_32                      TYPE x LENGTH 4,
              compressed_size             TYPE i,
              uncompressed_size           TYPE i,
              file_name_length            TYPE int2,
              extra_field_length          TYPE int2,
              " file name (variable size)
              " extra field (variable size)
            END OF ty_local_file_header,
            BEGIN OF ty_central_file_header,
              central_file_header_signature TYPE x LENGTH 4, " 02014b50
              version_made_by               TYPE x LENGTH 2,
              version_needed_to_extract     TYPE x LENGTH 2,
              general_purpose_bit_flag      TYPE x LENGTH 2,
              compression_method            TYPE x LENGTH 2,
              last_mod_file_time            TYPE int2,
              last_mod_file_date            TYPE int2,
              crc_32                        TYPE x LENGTH 4,
              compressed_size               TYPE i,
              uncompressed_size             TYPE i,
              file_name_length              TYPE int2, " field 12
              extra_field_length            TYPE int2, " field 13
              file_comment_length           TYPE int2, " field 14
              disk_number_start             TYPE int2,
              internal_file_attributes      TYPE x LENGTH 2,
              external_file_attributes      TYPE x LENGTH 4,
              rel_offset_of_local_header    TYPE x LENGTH 4,
              " file name                       (variable size defined in 12)
              " extra field                     (variable size defined in 13)
              " file comment                    (variable size defined in 14)
            END OF ty_central_file_header,
            BEGIN OF ty_end_of_central_dir,
              signature                      TYPE x LENGTH 4, " 0x06054b50
              number_of_this_disk            TYPE int2,
              disk_num_start_of_central_dir  TYPE int2,
              n_of_entries_in_central_dir_dk TYPE int2,
              n_of_entries_in_central_dir    TYPE int2,
              size_of_central_dir            TYPE i,
              offset_start_of_central_dir    TYPE i,
              file_comment_length            TYPE int2,
            END OF ty_end_of_central_dir.

    FIELD-SYMBOLS:
      <local_file_header_x>   TYPE x,
      <central_file_header_x> TYPE x,
      <end_of_central_dir_x>  TYPE x,
      <local_file_header>     TYPE ty_local_file_header,
      <central_file_header>   TYPE ty_central_file_header,
      <end_of_central_dir>    TYPE ty_end_of_central_dir.
    CONSTANTS:
      local_file_header_signature   TYPE x LENGTH 4 VALUE '504B0304',
      central_file_header_signature TYPE x LENGTH 4 VALUE '504B0102',
      end_of_central_dir_signature  TYPE x LENGTH 4 VALUE '504B0506'.
    DATA:
      dummy_local_file_header   TYPE ty_local_file_header,
      dummy_central_file_header TYPE ty_central_file_header,
      dummy_end_of_central_dir  TYPE ty_end_of_central_dir,
      local_file_header         TYPE ty_zip_structure,
      central_file_header       TYPE ty_zip_structure,
      end_of_central_dir        TYPE ty_zip_structure,
      offset                    TYPE i,
      max_offset                TYPE i.



    local_file_header = init_structure( length = 30 charset_bit = 60 structure = dummy_local_file_header ).
    ASSIGN local_file_header-ref_to_structure->* TO <local_file_header>.
    ASSIGN local_file_header-ref_to_x->* TO <local_file_header_x>.

    central_file_header = init_structure( length = 46 charset_bit = 76 structure = dummy_central_file_header ).
    ASSIGN central_file_header-ref_to_structure->* TO <central_file_header>.
    ASSIGN central_file_header-ref_to_x->* TO <central_file_header_x>.

    end_of_central_dir = init_structure( length = 22 charset_bit = 0 structure = dummy_end_of_central_dir ).
    ASSIGN end_of_central_dir-ref_to_structure->* TO <end_of_central_dir>.
    ASSIGN end_of_central_dir-ref_to_x->* TO <end_of_central_dir_x>.

    result = zip_xstring.

    offset = 0.
    max_offset = xstrlen( result ) - 4.
    WHILE offset <= max_offset.

      CASE result+offset(4).

        WHEN local_file_header_signature.

          read_zip( EXPORTING zip_xstring = result offset = offset CHANGING zip_structure = local_file_header ).

          CLEAR <local_file_header>-last_mod_file_date.
          CLEAR <local_file_header>-last_mod_file_time.

          write_zip( EXPORTING offset = offset CHANGING zip_structure = local_file_header zip_xstring = result ).

          offset = offset + local_file_header-length + <local_file_header>-file_name_length + <local_file_header>-extra_field_length + <local_file_header>-compressed_size.

        WHEN central_file_header_signature.

          read_zip( EXPORTING zip_xstring = result offset = offset CHANGING zip_structure = central_file_header ).

          CLEAR <central_file_header>-last_mod_file_date.
          CLEAR <central_file_header>-last_mod_file_time.

          write_zip( EXPORTING offset = offset CHANGING zip_structure = central_file_header zip_xstring = result ).

          offset = offset + central_file_header-length + <central_file_header>-file_name_length + <central_file_header>-extra_field_length + <central_file_header>-file_comment_length.

        WHEN end_of_central_dir_signature.

          read_zip( EXPORTING zip_xstring = result offset = offset CHANGING zip_structure = end_of_central_dir ).

          offset = offset + end_of_central_dir-length + <end_of_central_dir>-file_comment_length.

        WHEN OTHERS.
          RAISE EXCEPTION TYPE zcx_excel EXPORTING error = 'Invalid ZIP file'.

      ENDCASE.

    ENDWHILE.

  ENDMETHOD.

  METHOD read_zip.

    DATA:
      charset TYPE i.
    FIELD-SYMBOLS:
      <zip_structure_x> TYPE x,
      <zip_structure>   TYPE any.

    ASSIGN zip_structure-ref_to_x->* TO <zip_structure_x>.
    ASSIGN zip_structure-ref_to_structure->* TO <zip_structure>.

    <zip_structure_x> = zip_xstring+offset.

    IF zip_structure-charset_bit >= 1.
      GET BIT zip_structure-charset_bit OF <zip_structure_x> INTO charset.
    ENDIF.

    IF charset = 0.
      IF zip_structure-conv_in_ibm437 IS NOT BOUND.
        zip_structure-conv_in_ibm437 = cl_abap_conv_in_ce=>create(
                  encoding = '1107'
                  endian = 'L' ).
      ENDIF.
      zip_structure-conv_in_ibm437->convert_struc(
            EXPORTING input = <zip_structure_x>
                      view = zip_structure-view
            IMPORTING data = <zip_structure> ).
    ELSE.
      IF zip_structure-conv_in_utf8 IS NOT BOUND.
        zip_structure-conv_in_utf8 = cl_abap_conv_in_ce=>create(
                  encoding = '4110'
                  endian = 'L' ).
      ENDIF.
      zip_structure-conv_in_utf8->convert_struc(
            EXPORTING input = <zip_structure_x>
                      view = zip_structure-view
            IMPORTING data = <zip_structure> ).
    ENDIF.

  ENDMETHOD.


  METHOD write_zip.

    DATA:
      charset TYPE i.
    FIELD-SYMBOLS:
      <zip_structure_x> TYPE x,
      <zip_structure>   TYPE any.

    ASSIGN zip_structure-ref_to_x->* TO <zip_structure_x>.
    ASSIGN zip_structure-ref_to_structure->* TO <zip_structure>.

    IF zip_structure-charset_bit >= 1.
      GET BIT zip_structure-charset_bit OF <zip_structure_x> INTO charset.
    ENDIF.

    IF charset = 0.
      IF zip_structure-conv_out_ibm437 IS NOT BOUND.
        zip_structure-conv_out_ibm437 = cl_abap_conv_out_ce=>create(
                  encoding = '1107'
                  endian = 'L' ).
      ENDIF.
      zip_structure-conv_out_ibm437->convert_struc(
            EXPORTING data = <zip_structure>
                      view = zip_structure-view
            IMPORTING buffer = <zip_structure_x> ).
    ELSE.
      IF zip_structure-conv_out_utf8 IS NOT BOUND.
        zip_structure-conv_out_utf8 = cl_abap_conv_out_ce=>create(
                  encoding = '4110'
                  endian = 'L' ).
      ENDIF.
      zip_structure-conv_out_utf8->convert_struc(
            EXPORTING data = <zip_structure>
                      view = zip_structure-view
            IMPORTING buffer = <zip_structure_x> ).
    ENDIF.

    REPLACE SECTION OFFSET offset LENGTH zip_structure-length OF zip_xstring WITH <zip_structure_x> IN BYTE MODE.

  ENDMETHOD.


  METHOD init_structure.

    DATA:
      offset      TYPE i,
      rtts_struct TYPE REF TO cl_abap_structdescr.
    FIELD-SYMBOLS:
      <component> TYPE abap_compdescr.

    CREATE DATA result-ref_to_structure LIKE structure.
    result-length = length.
    result-charset_bit = charset_bit.
    CREATE DATA result-ref_to_x TYPE x LENGTH length.

    result-view = cl_abap_view_offlen=>create( ).
    offset = 0.
    rtts_struct ?= cl_abap_typedescr=>describe_by_data( structure ).
    LOOP AT rtts_struct->components ASSIGNING <component>.
      result-view->append( off = offset len = <component>-length ).
      offset = offset + <component>-length.
    ENDLOOP.

  ENDMETHOD.


ENDCLASS.

DATA filter TYPE text1024.
SELECT-OPTIONS s_filter FOR filter DEFAULT '01*' SIGN I OPTION CP." LOWER CASE.
PARAMETERS p_input TYPE string LOWER CASE DEFAULT 'C:\Users\sandra.rossi\Documents\SAP GUI\'.
PARAMETERS p_output TYPE string LOWER CASE DEFAULT 'C:\Users\sandra.rossi\Documents\SAP GUI\fromReader_'.

START-OF-SELECTION.
  TRY.
      NEW lcl_app( )->start_of_selection( ).
    CATCH cx_root INTO DATA(error).
      MESSAGE error TYPE 'I' DISPLAY LIKE 'E'.
  ENDTRY.
  ASSERT 1 = 1. " debug helper
