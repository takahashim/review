# Copyright (c) 2002-2007 Minero Aoki
#               2008-2009 Minero Aoki, Kenshi Muto
#               2010-2019 Minero Aoki, Kenshi Muto, TAKAHASHI Masayoshi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

require 'review/builder'
require 'review/latexutils'
require 'review/textutils'

module ReVIEW
  class LATEXBuilder < Builder
    include LaTeXUtils
    include TextUtils

    %i[dtp hd_chap].each do |e|
      Compiler.definline(e)
    end

    Compiler.defsingle(:latextsize, 1)

    def extname
      '.tex'
    end

    def builder_init_file
      @chapter.book.image_types = %w[.ai .eps .pdf .tif .tiff .png .bmp .jpg .jpeg .gif]
      @blank_needed = false
      @latex_tsize = nil
      @tsize = nil
      @table_caption = nil
      @cellwidth = nil
      @ol_num = nil
      @first_line_num = nil
      @sec_counter = SecCounter.new(5, @chapter)
      @foottext = {}
      setup_index
      initialize_metachars(@book.config['texcommand'])
    end
    private :builder_init_file

    def setup_index
      @index_db = {}
      @index_mecab = nil
      return true unless @book.config['pdfmaker']['makeindex']

      if @book.config['pdfmaker']['makeindex_dic']
        @index_db = load_idxdb(@book.config['pdfmaker']['makeindex_dic'])
      end
      return true unless @book.config['pdfmaker']['makeindex_mecab']
      begin
        begin
          require 'MeCab'
        rescue LoadError
          require 'mecab'
        end
        require 'nkf'
        @index_mecab = MeCab::Tagger.new(@book.config['pdfmaker']['makeindex_mecab_opts'])
      rescue LoadError
        error 'not found MeCab'
      end
    end

    def load_idxdb(file)
      table = {}
      File.foreach(file) do |line|
        key, value = *line.strip.split(/\t+/, 2)
        table[key] = value
      end
      table
    end

    def blank
      @blank_needed = true
    end
    private :blank

    def flush_blank
      if @blank_needed
        "\n"
      else
        ''
      end
    end

    def print(*s)
      if @blank_needed
        @output.puts
        @blank_needed = false
      end
      super
    end
    private :print

    def puts(*s)
      if @blank_needed
        @output.puts
        @blank_needed = false
      end
      super
    end
    private :puts

    def result
      if @chapter.is_a?(ReVIEW::Book::Part) && !@book.config.check_version('2', exception: false)
        puts '\end{reviewpart}'
      end
      @output.string
    end

    HEADLINE = {
      1 => 'chapter',
      2 => 'section',
      3 => 'subsection',
      4 => 'subsubsection',
      5 => 'paragraph',
      6 => 'subparagraph'
    }.freeze

    def headline(level, label, caption)
      buf = ''
      _, anchor = headline_prefix(level)
      headline_name = HEADLINE[level]
      if @chapter.is_a?(ReVIEW::Book::Part)
        if @book.config.check_version('2', exception: false)
          headline_name = 'part'
        elsif level == 1
          headline_name = 'part'
          buf << '\begin{reviewpart}' << "\n"
        end
      end
      prefix = ''
      if level > @book.config['secnolevel'] || (@chapter.number.to_s.empty? && level > 1)
        prefix = '*'
      end
      blank unless @output.pos == 0
      @doc_status[:caption] = true
      buf << flush_blank
      buf << macro(headline_name + prefix, caption) << "\n"
      @doc_status[:caption] = nil
      if prefix == '*' && level <= @book.config['toclevel'].to_i
        buf << "\\addcontentsline{toc}{#{headline_name}}{#{caption}}\n"
      end
      if level == 1
        buf << macro('label', chapter_label) << "\n"
      else
        buf << macro('label', sec_label(anchor)) << "\n"
        buf << macro('label', label) << "\n" if label
      end
      buf
    rescue
      error "unknown level: #{level}"
    end

    def nonum_begin(level, _label, caption)
      buf = ''
      blank unless @output.pos == 0
      @doc_status[:caption] = true
      buf << flush_blank
      buf << macro(HEADLINE[level] + '*', caption) << "\n"
      @doc_status[:caption] = nil
      buf << macro('addcontentsline', 'toc', HEADLINE[level], caption) << "\n"
      buf
    end

    def nonum_end(level)
      ''
    end

    def notoc_begin(level, _label, caption)
      buf = ''
      blank unless @output.pos == 0
      @doc_status[:caption] = true
      buf << flush_blank
      buf << macro(HEADLINE[level] + '*', caption) << "\n"
      @doc_status[:caption] = nil
      buf
    end

    def notoc_end(level)
      ''
    end

    def nodisp_begin(level, _label, caption)
      buf = ''
      if @output.pos != 0
        blank
      else
        buf << macro('clearpage') << "\n"
      end
      buf << flush_blank
      buf << macro('addcontentsline', 'toc', HEADLINE[level], caption) << "\n"
      # FIXME: headings
      buf
    end

    def nodisp_end(level)
      ''
    end

    def column_begin(level, label, caption)
      buf = ''
      blank
      @doc_status[:column] = true

      target = nil
      if label
        target = "\\hypertarget{#{column_label(label)}}{}"
      else
        target = "\\hypertarget{#{column_label(caption)}}{}"
      end

      @doc_status[:caption] = true
      buf << flush_blank
      if @book.config.check_version('2', exception: false)
        buf << '\\begin{reviewcolumn}' << "\n"
        buf << target << "\n"
        buf << macro('reviewcolumnhead', nil, caption) << "\n"
      else
        # ver.3
        buf << '\\begin{reviewcolumn}'
        buf << "[#{caption}#{target}]" << "\n"
      end
      @doc_status[:caption] = nil

      if level <= @book.config['toclevel'].to_i
        buf << "\\addcontentsline{toc}{#{HEADLINE[level]}}{#{caption}}" << "\n"
      end
      buf
    end

    def column_end(_level)
      buf = ''
      buf << flush_blank
      buf << '\\end{reviewcolumn}' << "\n"
      blank
      @doc_status[:column] = nil
      buf
    end

    def captionblock(type, lines, caption)
      buf = ''
      if @book.config.check_version('2', exception: false)
        type = 'minicolumn'
      end

      buf << flush_blank
      buf << "\\begin{review#{type}}"

      @doc_status[:caption] = true
      if @book.config.check_version('2', exception: false)
        buf << "\n"
        if caption.present?
          buf << "\\reviewminicolumntitle{#{caption}}" << "\n"
        end
      else
        if caption.present?
          buf << "[#{caption}]"
        end
        buf << "\n"
      end

      @doc_status[:caption] = nil
      blocked_lines = split_paragraph(lines)
      buf << blocked_lines.join("\n\n") << "\n"

      buf << "\\end{review#{type}}" << "\n"
      buf
    end

    def box(lines, caption = nil)
      buf = ''
      blank
      flush_blank
      buf << macro('reviewboxcaption', caption) << "\n" if caption.present?
      buf << '\begin{reviewbox}' << "\n"
      lines.each do |line|
        buf << detab(line) << "\n"
      end
      buf << '\end{reviewbox}' << "\n"
      blank
      buf
    end

    def ul_begin
      buf = ''
      blank
      buf << flush_blank
      buf << '\begin{itemize}' << "\n"
      buf
    end

    def ul_item(lines)
      buf = ''
      str = lines.join
      str.sub!(/\A(\[)/) { '\lbrack{}' }
      buf << '\item ' + str << "\n"
      buf
    end

    def ul_end
      buf = ''
      buf << '\end{itemize}' << "\n"
      blank
      buf
    end

    def ol_begin
      buf = ''
      blank
      buf << flush_blank
      buf << '\begin{enumerate}' << "\n"
      return buf unless @ol_num
      buf << "\\setcounter{enumi}{#{@ol_num - 1}}" << "\n"
      @ol_num = nil
      buf
    end

    def ol_item(lines, _num)
      buf = ''
      str = lines.join
      str.sub!(/\A(\[)/) { '\lbrack{}' }
      buf << flush_blank
      buf << '\item ' + str << "\n"
    end

    def ol_end
      buf = ''
      buf << '\end{enumerate}' << "\n"
      blank
      buf
    end

    def dl_begin
      buf = ''
      blank
      buf << flush_blank
      buf << '\begin{description}' << "\n"
    end

    def dt(str)
      buf = ''
      str.sub!(/\[/) { '\lbrack{}' }
      str.sub!(/\]/) { '\rbrack{}' }
#      buf << flush_blank
      buf << '\item[' + str + '] \mbox{} \\\\' << "\n"
      buf
    end

    def dd(lines)
      lines.join + "\n"
    end

    def dl_end
      buf = ''
      buf << '\end{description}' << "\n"
      blank
      buf
    end

    def paragraph(lines)
      buf = ''
      blank
      buf << flush_blank
      lines.each do |line|
        buf << line << "\n"
      end
      blank
      buf
    end

    def parasep
      buf = flush_blank
      buf << '\\parasep' << "\n"
      buf
    end

    def read(lines)
      latex_block 'quotation', lines
    end

    alias_method :lead, :read

    def highlight_listings?
      @book.config['highlight'] && @book.config['highlight']['latex'] == 'listings'
    end
    private :highlight_listings?

    def emlist(lines, caption = nil, lang = nil)
      buf = ''
      blank
      ##buf << flush_blank
      if highlight_listings?
        buf << common_code_block_lst(nil, lines, 'reviewemlistlst', 'title', caption, lang)
      else
        buf << common_code_block(nil, lines, 'reviewemlist', caption, lang) { |line, _idx| detab(line) + "\n" }
      end
      buf
    end

    def emlistnum(lines, caption = nil, lang = nil)
      buf = ''
      blank
      first_line_num = line_num
      ##buf << flush_blank
      if highlight_listings?
        buf << common_code_block_lst(nil, lines, 'reviewemlistnumlst', 'title', caption, lang, first_line_num: first_line_num)
      else
        buf << common_code_block(nil, lines, 'reviewemlist', caption, lang) { |line, idx| detab((idx + first_line_num).to_s.rjust(2) + ': ' + line) + "\n" }
      end
      buf
    end

    ## override Builder#list
    def list(lines, id, caption, lang = nil)
      buf = ''
      buf << flush_blank
      if highlight_listings?
        buf << common_code_block_lst(id, lines, 'reviewlistlst', 'caption', caption, lang)
      else
        buf << common_code_block(id, lines, 'reviewlist', caption, lang) { |line, _idx| detab(line) + "\n" }
      end
      buf
    end

    ## override Builder#listnum
    def listnum(lines, id, caption, lang = nil)
      buf = ''
      first_line_num = line_num
      buf << flush_blank
      if highlight_listings?
        buf << common_code_block_lst(id, lines, 'reviewlistnumlst', 'caption', caption, lang, first_line_num: first_line_num)
      else
        buf << common_code_block(id, lines, 'reviewlist', caption, lang) { |line, idx| detab((idx + first_line_num).to_s.rjust(2) + ': ' + line) + "\n" }
      end
      buf
    end

    def cmd(lines, caption = nil, lang = nil)
      buf = ''
      blank
      if highlight_listings?
        buf << common_code_block_lst(nil, lines, 'reviewcmdlst', 'title', caption, lang)
      else
        buf << common_code_block(nil, lines, 'reviewcmd', caption, lang) { |line, _idx| detab(line) + "\n" }
      end
      buf
    end

    def common_code_block(id, lines, command, caption, _lang)
      buf = ''
      @doc_status[:caption] = true
      buf << flush_blank
      unless @book.config.check_version('2', exception: false)
        buf << '\\begin{reviewlistblock}' << "\n"
      end
      if caption.present?
        if command =~ /emlist/ || command =~ /cmd/ || command =~ /source/
          buf << macro(command + 'caption', caption) << "\n"
        else
          begin
            if get_chap.nil?
              buf << macro('reviewlistcaption', "#{I18n.t('list')}#{I18n.t('format_number_header_without_chapter', [@chapter.list(id).number])}#{I18n.t('caption_prefix')}#{caption}") << "\n"
            else
              buf << macro('reviewlistcaption', "#{I18n.t('list')}#{I18n.t('format_number_header', [get_chap, @chapter.list(id).number])}#{I18n.t('caption_prefix')}#{caption}") << "\n"
            end
          rescue KeyError
            error "no such list: #{id}"
          end
        end
      end
      @doc_status[:caption] = nil
      body = ''
      lines.each_with_index do |line, idx|
        body.concat(yield(line, idx))
      end
      buf << macro('begin', command) << "\n"
      buf << body
      buf << macro('end', command) << "\n"
      unless @book.config.check_version('2', exception: false)
        buf << '\\end{reviewlistblock}' << "\n"
      end
      blank
      buf
    end

    def common_code_block_lst(_id, lines, command, title, caption, lang, first_line_num: 1)
      buf = ''
      if title == 'title' && caption.blank? && @book.config.check_version('2', exception: false)
        buf << '\vspace{-1.5em}'
      end
      body = lines.inject('') { |i, j| i + detab(unescape(j)) + "\n" }
      args = make_code_block_args(title, caption, lang, first_line_num: first_line_num)
      buf << %Q(\\begin{#{command}}[#{args}]) << "\n"
      buf << body
      buf << %Q(\\end{#{command}}) << "\n"
      blank
      buf
    end

    def make_code_block_args(title, caption, lang, first_line_num: 1)
      caption_str = compile_inline((caption || ''))
      if title == 'title' && caption_str == '' && @book.config.check_version('2', exception: false)
        caption_str = '\relax' ## dummy charactor to remove lstname
      end
      lexer = if @book.config['highlight'] && @book.config['highlight']['lang']
                @book.config['highlight']['lang'] # default setting
              else
                ''
              end
      lexer = lang if lang.present?
      args = "language={#{lexer}}"
      if title == 'title' && caption_str == ''
        # ignore
      else
        args = "#{title}={#{caption_str}}," + args
      end
      if first_line_num != 1
        args << ",firstnumber=#{first_line_num}"
      end
      args
    end

    def source(lines, caption = nil, lang = nil)
      if highlight_listings?
        common_code_block_lst(nil, lines, 'reviewsourcelst', 'title', caption, lang)
      else
        common_code_block(nil, lines, 'reviewsource', caption, lang) { |line, _idx| detab(line) + "\n" }
      end
    end

    def image_header(id, caption)
      ''
    end

    def handle_metric(str)
      if @book.config['image_scale2width'] && str =~ /\Ascale=([\d.]+)\Z/
        return "width=#{$1}\\maxwidth"
      end
      str
    end

    def result_metric(array)
      array.join(',')
    end

    def image_image(id, caption, metric)
      buf = ''
      metrics = parse_metric('latex', metric)
      # image is always bound here
      buf << flush_blank
      buf << "\\begin{reviewimage}%%#{id}" << "\n"
      if metrics.present?
        buf << "\\includegraphics[#{metrics}]{#{@chapter.image(id).path}}" << "\n"
      else
        buf << "\\includegraphics[width=\\maxwidth]{#{@chapter.image(id).path}}" << "\n"
      end
      @doc_status[:caption] = true

      if @book.config.check_version('2', exception: false)
        buf << macro('caption', caption) << "\n" if caption.present?
      else
        buf << macro('reviewimagecaption', caption) << "\n" if caption.present?
      end
      @doc_status[:caption] = nil
      buf << macro('label', image_label(id)) << "\n"
      buf << '\end{reviewimage}' << "\n"
      buf
    end

    def image_dummy(id, caption, lines)
      buf = ''
      warn "image not bound: #{id}"
      buf << '\begin{reviewdummyimage}' << "\n"
      # path = @chapter.image(id).path
      buf << "--[[path = #{id} (#{existence(id)})]]--\n"
      lines.each do |line|
        buf << detab(line.rstrip) << "\n"
      end
      buf << macro('label', image_label(id)) << "\n"
      @doc_status[:caption] = true
      if @book.config.check_version('2', exception: false)
        buf << macro('caption', caption) << "\n" if caption.present?
      else
        buf << macro('reviewimagecaption', caption) << "\n" if caption.present?
      end
      @doc_status[:caption] = nil
      buf << '\end{reviewdummyimage}' << "\n"
    end

    def existence(id)
      @chapter.image(id).bound? ? 'exist' : 'not exist'
    end
    private :existence

    def image_label(id, chapter = nil)
      chapter ||= @chapter
      "image:#{chapter.id}:#{id}"
    end
    private :image_label

    def chapter_label
      "chap:#{@chapter.id}"
    end
    private :chapter_label

    def sec_label(sec_anchor)
      "sec:#{sec_anchor}"
    end
    private :sec_label

    def table_label(id, chapter = nil)
      chapter ||= @chapter
      "table:#{chapter.id}:#{id}"
    end
    private :table_label

    def bib_label(id)
      "bib:#{id}"
    end
    private :bib_label

    def column_label(id, chapter = @chapter)
      filename = chapter.id
      num = chapter.column(id).number
      "column:#{filename}:#{num}"
    end
    private :column_label

    def indepimage(lines, id, caption = nil, metric = nil)
      buf = ''
      metrics = parse_metric('latex', metric)

      if @chapter.image(id).path
        buf << "\\begin{reviewimage}%%#{id}" << "\n"
        if metrics.present?
          buf << "\\includegraphics[#{metrics}]{#{@chapter.image(id).path}}" << "\n"
        else
          buf << "\\includegraphics[width=\\maxwidth]{#{@chapter.image(id).path}}" << "\n"
        end
      else
        warn "image not bound: #{id}"
        buf << '\begin{reviewdummyimage}' << "\n"
        buf << "--[[path = #{id} (#{existence(id)})]]--" << "\n"
        lines.each do |line|
          buf << detab(line.rstrip) << "\n"
        end
      end

      @doc_status[:caption] = true
      if caption.present?
        buf << macro('reviewindepimagecaption',
                     %Q(#{I18n.t('numberless_image')}#{I18n.t('caption_prefix')}#{caption})) << "\n"
      end
      @doc_status[:caption] = nil

      if @chapter.image(id).path
        buf << '\end{reviewimage}' << "\n"
      else
        buf << '\end{reviewdummyimage}' << "\n"
      end
      buf
    end

    alias_method :numberlessimage, :indepimage

    def table(lines, id = nil, caption = nil)
      buf = ''
      rows = []
      sepidx = nil
      buf << flush_blank
      lines.each_with_index do |line, idx|
        if /\A[\=\{\-\}]{12}/ =~ line
          # just ignore
          # error "too many table separator" if sepidx
          sepidx ||= idx
          next
        end
        rows.push(line.strip.split(/\t+/).map { |s| s.sub(/\A\./, '') })
      end
      rows = adjust_n_cols(rows)

      begin
        buf << table_header(id, caption) if caption.present?
      rescue KeyError
        error "no such table: #{id}"
      end
      return buf if rows.empty?
      buf << table_begin(rows.first.size)
      if sepidx
        sepidx.times do
          cno = -1
          buf << tr(rows.shift.map do |s|
                      cno += 1
                      th(s, @cellwidth[cno])
             end)
        end
        rows.each do |cols|
          cno = -1
          buf << tr(cols.map do |s|
                      cno += 1
                      td(s, @cellwidth[cno])
                    end)
        end
      else
        rows.each do |cols|
          h, *cs = *cols
          cno = 0
          buf << tr([th(h, @cellwidth[0])] +
                    cs.map do |s|
                      cno += 1
                      td(s, @cellwidth[cno])
                    end)
        end
      end
      buf << table_end
      buf
    end

    def table_header(id, caption)
      buf = ''
      if id.nil?
        if caption.present?
          @table_caption = true
          @doc_status[:caption] = true
          if @book.config.check_version('2', exception: false)
            buf << "\\begin{table}[h]%%#{id}" << "\n"
          else
            buf << "\\begin{table}%%#{id}" << "\n"
          end
          buf << macro('reviewtablecaption*', caption) << "\n"
          @doc_status[:caption] = nil
        end
      else
        if caption.present?
          @table_caption = true
          @doc_status[:caption] = true
          if @book.config.check_version('2', exception: false)
            buf << "\\begin{table}[h]%%#{id}" << "\n"
          else
            buf << "\\begin{table}%%#{id}" << "\n"
          end
          buf << macro('reviewtablecaption', caption) << "\n"
          @doc_status[:caption] = nil
        end
        buf << macro('label', table_label(id)) << "\n"
      end
      buf
    end

    def table_begin(ncols)
      buf = ''
      if @latex_tsize
        @tsize = @latex_tsize
      end

      if @tsize
        if @tsize =~ /\A[\d., ]+\Z/
          @cellwidth = @tsize.split(/\s*,\s*/)
          @cellwidth.collect! { |i| "p{#{i}mm}" }
          buf << macro('begin', 'reviewtable', '|' + @cellwidth.join('|') + '|') << "\n"
        else
          @cellwidth = separate_tsize(@tsize)
          buf << macro('begin', 'reviewtable', @tsize) << "\n"
        end
      else
        buf << macro('begin', 'reviewtable', (['|'] * (ncols + 1)).join('l')) << "\n"
        @cellwidth = ['l'] * ncols
      end
      buf << '\\hline' << "\n"
      buf
    end

    def separate_tsize(size)
      buf = ''
      ret = []
      s = ''
      brace = nil
      size.split('').each do |ch|
        case ch
        when '|'
          next
        when '{'
          brace = true
          s << ch
        when '}'
          brace = nil
          s << ch
          ret << s
          s = ''
        else
          if brace
            s << ch
          else
            if s.empty?
              s << ch
            else
              ret << s
              s = ch
            end
          end
        end
      end

      unless s.empty?
        ret << s
      end

      ret
    end

    def table_separator
      # puts '\hline'
      ''
    end

    def th(s, cellwidth = 'l')
      buf = ''
      if /\\\\/ =~ s
        if !@book.config.check_version('2', exception: false) && cellwidth =~ /\{/
          buf << macro('reviewth', s.gsub("\\\\\n", '\\newline{}'))
        else
          ## use shortstack for @<br>
          buf << macro('reviewth', macro('shortstack[l]', s))
        end
      else
        macro('reviewth', s)
      end
    end

    def td(s, cellwidth = 'l')
      buf = ''
      if /\\\\/ =~ s
        if !@book.config.check_version('2', exception: false) && cellwidth =~ /\{/
          buf << s.gsub("\\\\\n", '\\newline{}')
        else
          ## use shortstack for @<br>
          buf << macro('shortstack[l]', s)
        end
      else
        s
      end
    end

    def tr(rows)
      buf = ''
      buf << rows.join(' & ')
      buf << ' \\\\  \hline' << "\n"
      buf
    end

    def table_end
      buf = ''
      buf << macro('end', 'reviewtable') << "\n"
      buf << '\end{table}' << "\n" if @table_caption
      @table_caption = nil
      @tsize = nil
      @latex_tsize = nil
      @cellwidth = nil
      blank
      buf
    end

    def emtable(lines, caption = nil)
      table(lines, nil, caption)
    end

    def imgtable(lines, id, caption = nil, metric = nil)
      buf = ''
      unless @chapter.image(id).bound?
        warn "image not bound: #{id}"
        buf << image_dummy(id, caption, lines)
        return buf
      end

      begin
        if caption.present?
          @table_caption = true
          @doc_status[:caption] = true
          buf << "\\begin{table}[h]%%#{id}" << "\n"
          buf << macro('reviewimgtablecaption', caption) << "\n"
          @doc_status[:caption] = nil
        end
        buf << macro('label', table_label(id)) << "\n"
      rescue ReVIEW::KeyError
        error "no such table: #{id}"
      end
      buf << imgtable_image(id, caption, metric)

      buf << '\end{table}' << "\n" if @table_caption
      @table_caption = nil
      blank
      buf
    end

    def imgtable_image(id, _caption, metric)
      buf = ''
      metrics = parse_metric('latex', metric)
      # image is always bound here
      buf << "\\begin{reviewimage}%%#{id}" << "\n"
      if metrics.present?
        buf << "\\includegraphics[#{metrics}]{#{@chapter.image(id).path}}" << "\n"
      else
        buf << "\\includegraphics[width=\\maxwidth]{#{@chapter.image(id).path}}" << "\n"
      end
      buf << '\end{reviewimage}' << "\n"
      buf
    end

    def quote(lines)
      latex_block 'quote', lines
    end

    def center(lines)
      latex_block 'center', lines
    end

    alias_method :centering, :center

    def flushright(lines)
      latex_block 'flushright', lines
    end

    def texequation(lines, id = nil, caption = '')
      buf = ''
      blank
      buf << flush_blank

      if id
        buf << macro('begin', 'reviewequationblock') << "\n"
        if get_chap.nil?
          buf << macro('reviewequationcaption', "#{I18n.t('equation')}#{I18n.t('format_number_header_without_chapter', [@chapter.equation(id).number])}#{I18n.t('caption_prefix')}#{caption}") << "\n"
        else
          buf << macro('reviewequationcaption', "#{I18n.t('equation')}#{I18n.t('format_number_header', [get_chap, @chapter.equation(id).number])}#{I18n.t('caption_prefix')}#{caption}") << "\n"
        end
      end

      buf << macro('begin', 'equation*') << "\n"
      lines.each do |line|
        buf << unescape(line) << "\n"
      end
      buf << macro('end', 'equation*') << "\n"

      if id
        buf << macro('end', 'reviewequationblock') << "\n"
      end

      blank
      buf
    end

    def latex_block(type, lines)
      buf = ''
      blank
      buf << flush_blank
      buf << macro('begin', type) << "\n"
      blocked_lines = split_paragraph(lines)
      buf << blocked_lines.join("\n\n") << "\n"
      buf << macro('end', type) << "\n"
      blank
      buf
    end
    private :latex_block

    def direct(lines, fmt)
      buf = ''
      return buf unless fmt == 'latex'
      lines.each do |line|
        buf << line << "\n"
      end
      buf
    end

    def comment(lines, comment = nil)
      buf = ''
      return buf unless @book.config['draft']
      lines ||= []
      unless comment.blank?
        lines.unshift comment
      end
      str = lines.join('\par ')
      buf << macro('pdfcomment', str) << "\n"
      buf
    end

    def hr
      '\hrule' + "\n"
    end

    def label(id)
      macro('label', id) + "\n"
    end

    def pagebreak
      '\pagebreak' + "\n"
    end

    def blankline
      '\vspace*{\baselineskip}' + "\n"
    end

    def noindent
      '\noindent'
    end

    def inline_chapref(id)
      title = super
      if @book.config['chapterlink']
        "\\hyperref[chap:#{id}]{#{title}}"
      else
        title
      end
    rescue KeyError
      error "unknown chapter: #{id}"
      nofunc_text("[UnknownChapter:#{id}]")
    end

    def inline_chap(id)
      if @book.config['chapterlink']
        "\\hyperref[chap:#{id}]{#{@book.chapter_index.number(id)}}"
      else
        @book.chapter_index.number(id)
      end
    rescue KeyError
      error "unknown chapter: #{id}"
      nofunc_text("[UnknownChapter:#{id}]")
    end

    def inline_title(id)
      title = super
      if @book.config['chapterlink']
        "\\hyperref[chap:#{id}]{#{title}}"
      else
        title
      end
    rescue KeyError
      error "unknown chapter: #{id}"
      nofunc_text("[UnknownChapter:#{id}]")
    end

    def inline_pageref(id)
      "\\pageref{#{id}}"
    end

    # FIXME: use TeX native label/ref.
    def inline_list(id)
      chapter, id = extract_chapter_id(id)
      if get_chap(chapter).nil?
        macro('reviewlistref', I18n.t('format_number_without_chapter', [chapter.list(id).number]))
      else
        macro('reviewlistref', I18n.t('format_number', [get_chap(chapter), chapter.list(id).number]))
      end
    rescue KeyError
      error "unknown list: #{id}"
    end

    def inline_table(id)
      chapter, id = extract_chapter_id(id)
      if get_chap(chapter).nil?
        macro('reviewtableref', I18n.t('format_number_without_chapter', [chapter.table(id).number]), table_label(id, chapter))
      else
        macro('reviewtableref', I18n.t('format_number', [get_chap(chapter), chapter.table(id).number]), table_label(id, chapter))
      end
    rescue KeyError
      error "unknown table: #{id}"
    end

    def inline_img(id)
      chapter, id = extract_chapter_id(id)
      if get_chap(chapter).nil?
        macro('reviewimageref', I18n.t('format_number_without_chapter', [chapter.image(id).number]), image_label(id, chapter))
      else
        macro('reviewimageref', I18n.t('format_number', [get_chap(chapter), chapter.image(id).number]), image_label(id, chapter))
      end
    rescue KeyError
      error "unknown image: #{id}"
    end

    def inline_eq(id)
      chapter, id = extract_chapter_id(id)
      if get_chap(chapter).nil?
        macro('reviewequationref', I18n.t('format_number_without_chapter', [chapter.equation(id).number]))
      else
        macro('reviewequationref', I18n.t('format_number', [get_chap(chapter), chapter.equation(id).number]))
      end
    rescue KeyError
      error "unknown equation: #{id}"
    end

    def footnote(id, content)
      if @book.config['footnotetext'] || @foottext[id]
        puts macro("footnotetext[#{@chapter.footnote(id).number}]", compile_inline(content.strip))
      end
    end

    def inline_fn(id)
      if @book.config['footnotetext']
        macro("footnotemark[#{@chapter.footnote(id).number}]", '')
      elsif @doc_status[:caption] || @doc_status[:table] || @doc_status[:column]
        @foottext[id] = @chapter.footnote(id).number
        macro('protect\\footnotemark', '')
      else
        macro('footnote', compile_inline(@chapter.footnote(id).content.strip))
      end
    rescue KeyError
      error "unknown footnote: #{id}"
    end

    BOUTEN = '・'.freeze

    def inline_bou(str)
      macro('reviewbou', escape(str))
    end

    def compile_ruby(base, ruby)
      macro('ruby', escape(base), escape(ruby).gsub('\\textbar{}', '|'))
    end

    # math
    def inline_m(str)
      if @book.config.check_version('2', exception: false)
        " $#{str}$ "
      else
        "$#{str}$"
      end
    end

    # hidden index
    def inline_hi(str)
      index(str)
    end

    # index -> italic
    def inline_i(str)
      if @book.config.check_version('2', exception: false)
        macro('textit', escape(str))
      else
        macro('reviewit', escape(str))
      end
    end

    # index
    def inline_idx(str)
      escape(str) + index(str)
    end

    # hidden index
    def inline_hidx(str)
      index(str)
    end

    # bold
    def inline_b(str)
      if @book.config.check_version('2', exception: false)
        macro('textbf', escape(str))
      else
        macro('reviewbold', escape(str))
      end
    end

    # line break
    def inline_br(_str)
      "\\\\\n"
    end

    def inline_dtp(_str)
      # ignore
      ''
    end

    ## @<code> is same as @<tt>
    def inline_code(str)
      if @book.config.check_version('2', exception: false)
        macro('texttt', escape(str))
      else
        macro('reviewcode', escape(str))
      end
    end

    def nofunc_text(str)
      escape(str)
    end

    def inline_tt(str)
      if @book.config.check_version('2', exception: false)
        macro('texttt', escape(str))
      else
        macro('reviewtt', escape(str))
      end
    end

    def inline_del(str)
      macro('reviewstrike', escape(str))
    end

    def inline_tti(str)
      if @book.config.check_version('2', exception: false)
        macro('texttt', macro('textit', escape(str)))
      else
        macro('reviewtti', escape(str))
      end
    end

    def inline_ttb(str)
      if @book.config.check_version('2', exception: false)
        macro('texttt', macro('textbf', escape(str)))
      else
        macro('reviewttb', escape(str))
      end
    end

    def inline_bib(id)
      macro('reviewbibref', "[#{@chapter.bibpaper(id).number}]", bib_label(id))
    end

    def inline_hd_chap(chap, id)
      n = chap.headline_index.number(id)
      if n.present? && chap.number && over_secnolevel?(n)
        str = I18n.t('hd_quote', [chap.headline_index.number(id), compile_inline(chap.headline(id).caption)])
      else
        str = I18n.t('hd_quote_without_number', compile_inline(chap.headline(id).caption))
      end
      if @book.config['chapterlink']
        anchor = n.gsub(/\./, '-')
        macro('reviewsecref', str, sec_label(anchor))
      else
        str
      end
    end

    def inline_column_chap(chapter, id)
      macro('reviewcolumnref',
            I18n.t('column', compile_inline(chapter.column(id).caption)),
            column_label(id, chapter))
    rescue KeyError
      error "unknown column: #{id}"
    end

    def inline_raw(str)
      super(str)
    end

    def inline_sub(str)
      macro('textsubscript', escape(str))
    end

    def inline_sup(str)
      macro('textsuperscript', escape(str))
    end

    def inline_em(str)
      macro('reviewem', escape(str))
    end

    def inline_strong(str)
      macro('reviewstrong', escape(str))
    end

    def inline_u(str)
      macro('reviewunderline', escape(str))
    end

    def inline_ami(str)
      macro('reviewami', escape(str))
    end

    def inline_icon(id)
      if @chapter.image(id).path
        macro('includegraphics', @chapter.image(id).path)
      else
        warn "image not bound: #{id}"
        "\\verb|--[[path = #{id} (#{existence(id)})]]--|"
      end
    end

    def inline_uchar(str)
      if @texcompiler && @texcompiler.start_with?('platex')
        # with otf package
        macro('UTF', escape(str))
      else
        # passthrough
        [str.to_i(16)].pack('U')
      end
    end

    def inline_comment(str)
      if @book.config['draft']
        macro('pdfcomment', escape(str))
      else
        ''
      end
    end

    def inline_tcy(str)
      macro('rensuji', escape(str))
    end

    def inline_balloon(str)
      macro('reviewballoon', escape(str))
    end

    def bibpaper_header(id, caption)
      buf = ''
      buf << "[#{@chapter.bibpaper(id).number}] #{caption}" << "\n"
      buf << macro('label', bib_label(id)) << "\n"
      buf
    end

    def bibpaper_bibpaper(_id, _caption, lines)
      buf = ''
      buf << split_paragraph(lines).join << "\n"
      buf << "\n"
      buf
    end

    def index(str)
      sa = str.split('<<>>')

      sa.map! do |item|
        if @index_db[item]
          escape_index(escape(@index_db[item])) + '@' + escape_index(escape(item))
        else
          if item =~ /\A[[:ascii:]]+\Z/ || @index_mecab.nil?
            esc_item = escape_index(escape(item))
            if esc_item != item
              "#{escape_index(item)}@#{esc_item}"
            else
              esc_item
            end
          else
            yomi = NKF.nkf('-w --hiragana', @index_mecab.parse(item).force_encoding('UTF-8').chomp)
            escape_index(escape(yomi)) + '@' + escape_index(escape(item))
          end
        end
      end

      "\\index{#{sa.join('!')}}"
    end

    def compile_kw(word, alt)
      if alt
        macro('reviewkw', escape(word)) + "（#{escape(alt.strip)}）"
      else
        macro('reviewkw', escape(word))
      end
    end

    def compile_href(url, label)
      if /\A[a-z]+:/ =~ url
        if label
          macro('href', escape_url(url), escape(label))
        else
          macro('url', escape_url(url))
        end
      else
        macro('ref', url)
      end
    end

    def latextsize(str)
      @latex_tsize = str
      ''
    end

    def image_ext
      'pdf'
    end

    def olnum(num)
      @ol_num = num.to_i
    end
  end
end
