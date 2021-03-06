module Vmdb
  module GlobalMethods
    def is_numeric?(n)
      Float n
    rescue
      false
    else
      true
    end

    # Check to see if a field contains a valid integer
    def is_integer?(n)
      Integer n
    rescue
      false
    else
      true
    end

    # Copy a hash, duplicating any embedded hashes/arrays contained within
    def copy_hash(hashin)
      hashin.deep_clone
    end

    # Copy an array, duplicating any embedded hashes/arrays contained within
    def copy_array(arrayin)
      arrayin.deep_clone
    end

    def column_type(model, column)
      MiqExpression.col_type(model, column)
    end

    # Had to add timezone methods here, they are being called from models
    # returns formatted time in specified timezone and format
    def format_timezone(time, timezone = Time.zone.name, ftype = "view")
      timezone = timezone.name if timezone.kind_of?(ActiveSupport::TimeZone)   # If a Timezone object comes in, just get the name
      if !time.blank?
        new_time = time.in_time_zone(timezone)
        case ftype
        when "gtl"                                  # for gtl views
          new_time = new_time.strftime("%m/%d/%y %H:%M:%S %Z")
        when "on_at"                                  # for gtl views
          new_time = new_time.strftime("on %m/%d/%y at %H:%M:%S %Z")
        when "fname"                                # for download filename
          new_time = new_time.strftime("%Y_%m_%d")
        when "date"                                 # for just mm/dd/yy
          new_time = new_time.strftime("%m/%d/%y")
        when "datetime"                             # mm/dd/yy hh:mm:ss
          new_time = new_time.strftime("%m/%d/%y %H:%M:%S")
        when "export_filename", "support_log_fname"    # for export/log filename
          new_time = new_time.strftime("%Y%m%d_%H%M%S")
        when "tl"
          new_time = new_time.strftime("%a %b %d %Y %H:%M:%S") + " " + Time.zone.to_s
          new_time = new_time.gsub(/\) [a-zA-Z0-9\s\S]*/, ")")
        when "raw"                                  # return without formatting
        when "compare_hdr"                          # for drift/compare headers
          new_time = new_time.strftime("%m/%d/%y %H:%M %Z")
        when "widget_footer"                        # for widget footers
          new_time = new_time.strftime("%m/%d/%y %H:%M")
        else                                        # for summary screens
          new_time = new_time.strftime("%a %b %d %H:%M:%S %Z %Y")
        end
      else    # if time is nil
        new_time = ""
      end
      new_time
    end

    # Get dictionary name with default settings
    def ui_lookup(options = {})
      # Pass in singular or plural key to determine format of returned string
      if options[:table]
        ui_lookup_for_table(options[:table]).singularize
      elsif options[:tables]
        ui_lookup_for_table(options[:tables]).pluralize
      elsif options[:model]
        ui_lookup_for_model(options[:model]).singularize
      elsif options[:models]
        ui_lookup_for_model(options[:models]).pluralize
      elsif options[:ems_cluster_types]
        ui_lookup_for_ems_cluster_types(options[:ems_cluster_types])
      elsif options[:ui_title]
        ui_lookup_for_title(options[:ui_title])
      else
        ''
      end
    end

    def ui_lookup_for_table(text)
      # Pass in singular or plural key to determine format of returned string
      Dictionary.gettext(text, :type => :table, :notfound => :titleize)
    end

    def ui_lookup_for_model(text)
      Dictionary.gettext(text, :type => :model, :notfound => :titleize)
    end

    def ui_lookup_for_ems_cluster_types(text)
      Dictionary.gettext(text, :type => :ems_cluster_types, :notfound => :titleize)
    end

    def ui_lookup_for_title(text)
      Dictionary.gettext(text, :type => :ui_title, :notfound => :titleize)
    end

    # Wrap a report html table body with html table tags and headers for the columns
    def report_build_html_table(report, table_body)
      html = ''
      html << "<table class='table table-striped table-bordered'>"
      html << "<thead>"
      html << "<tr>"

      # table headings
      unless report.headers.nil?
        report.headers.each do |h|
          html << "<th>" << CGI.escapeHTML(h.to_s) << "</th>"
        end
        html << "</tr>"
        html << "</thead>"
      end
      html << '<tbody>'
      html << table_body << '</tbody></table>'
    end
  end
end
