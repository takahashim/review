# Copyright (c) 2008-2019 Minero Aoki, Kenshi Muto, Masayoshi Takahashi,
#                         KADO Masanori
#               2002-2007 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'review/builder'
require 'review/htmlutils'
require 'review/template'
require 'review/textutils'
require 'review/webtocprinter'
require 'digest'
require 'tmpdir'
require 'open3'

module ReVIEW
  class HTMLBuilder < Builder
    include TextUtils
    include HTMLUtils

    [:ref].each do |e|
      Compiler.definline(e)
    end
    Compiler.defblock(:planning, 0..1)
    Compiler.defblock(:best, 0..1)
    Compiler.defblock(:security, 0..1)
    Compiler.defblock(:point, 0..1)
    Compiler.defblock(:shoot, 0..1)

    def pre_paragraph
      '<p>'
    end

    def post_paragraph
      '</p>'
    end

    def extname
      ".#{@book.config['htmlext']}"
    end

    def builder_init
    end
    private :builder_init

    def builder_init_file
      @noindent = nil
      @ol_num = nil
      @warns = []
      @errors = []
      @chapter.book.image_types = %w[.png .jpg .jpeg .gif .svg]
      @column = 0
      @sec_counter = SecCounter.new(5, @chapter)
      @nonum_counter = 0
      @first_line_num = nil
      @body_ext = nil
      @toc = nil
    end
    private :builder_init_file

    def layoutfile
      if @book.config.maker == 'webmaker'
        htmldir = 'web/html'
        localfilename = 'layout-web.html.erb'
      else
        htmldir = 'html'
        localfilename = 'layout.html.erb'
      end
      if @book.htmlversion == 5
        htmlfilename = File.join(htmldir, 'layout-html5.html.erb')
      else
        htmlfilename = File.join(htmldir, 'layout-xhtml1.html.erb')
      end

      layout_file = File.join(@book.basedir, 'layouts', localfilename)
      if !File.exist?(layout_file) && File.exist?(File.join(@book.basedir, 'layouts', 'layout.erb'))
        raise ReVIEW::ConfigError, 'layout.erb is obsoleted. Please use layout.html.erb.'
      end
      if File.exist?(layout_file)
        if ENV['REVIEW_SAFE_MODE'].to_i & 4 > 0
          warn %Q(user's layout is prohibited in safe mode. ignored.)
          layout_file = File.expand_path(htmlfilename, ReVIEW::Template::TEMPLATE_DIR)
        end
      else
        layout_file = File.expand_path(htmlfilename, ReVIEW::Template::TEMPLATE_DIR)
      end
      layout_file
    end

    def result
      # default XHTML header/footer
      @title = strip_html(compile_inline(@chapter.title))
      @body = @output.string
      @language = @book.config['language']
      @stylesheets = @book.config['stylesheet']
      @next = @chapter.next_chapter
      @prev = @chapter.prev_chapter
      @next_title = @next ? compile_inline(@next.title) : ''
      @prev_title = @prev ? compile_inline(@prev.title) : ''

      if @book.config.maker == 'webmaker'
        @toc = ReVIEW::WEBTOCPrinter.book_to_string(@book)
      end

      ReVIEW::Template.load(layoutfile).result(binding)
    end

    def xmlns_ops_prefix
      if @book.config['epubversion'].to_i == 3
        'epub'
      else
        'ops'
      end
    end

    def headline(level, label, caption)
      buf = ""
      prefix, anchor = headline_prefix(level)
      if prefix
        prefix = %Q(<span class="secno">#{prefix}</span>)
      end
      buf << "\n" if level > 1
      a_id = ''
      if anchor
        a_id = %Q(<a id="h#{anchor}"></a>)
      end

      if caption.empty?
        buf << a_id + "\n" if label
      elsif label
        buf << %Q(<h#{level} id="#{normalize_id(label)}">#{a_id}#{prefix}#{caption}</h#{level}>) + "\n"
      else
        buf << %Q(<h#{level}>#{a_id}#{prefix}#{caption}</h#{level}>) + "\n"
      end
      buf
    end

    def nonum_begin(level, label, caption)
      buf = ""
      @nonum_counter += 1
      buf << "\n" if level > 1
      return unless caption.present?
      if label
        buf << %Q(<h#{level} id="#{normalize_id(label)}">#{compile_inline(caption)}</h#{level}>) + "\n"
      else
        id = normalize_id("#{@chapter.name}_nonum#{@nonum_counter}")
        buf << %Q(<h#{level} id="#{id}">#{compile_inline(caption)}</h#{level}>) + "\n"
      end
      buf
    end

    def nonum_end(level)
    end

    def notoc_begin(level, label, caption)
      buf = ""
      @nonum_counter += 1
      buf << "\n" if level > 1
      return unless caption.present?
      if label
        buf << %Q(<h#{level} id="#{normalize_id(label)}" notoc="true">#{compile_inline(caption)}</h#{level}>) + "\n"
      else
        id = normalize_id("#{@chapter.name}_nonum#{@nonum_counter}")
        buf << %Q(<h#{level} id="#{id}" notoc="true">#{compile_inline(caption)}</h#{level}>) + "\n"
      end
      buf
    end

    def notoc_end(level)
    end

    def nodisp_begin(level, label, caption)
      buf = ""
      @nonum_counter += 1
      buf << "\n" if level > 1
      return unless caption.present?
      if label
        buf << %Q(<a id="#{normalize_id(label)}" /><h#{level} id="#{normalize_id(label)}" hidden="true">#{compile_inline(caption)}</h#{level}>) + "\n"
      else
        id = normalize_id("#{@chapter.name}_nonum#{@nonum_counter}")
        buf << %Q(<a id="#{id}" /><h#{level} id="#{id}" hidden="true">#{compile_inline(caption)}</h#{level}>) + "\n"
      end
      buf
    end

    def nodisp_end(level)
    end

    def column_begin(level, label, caption)
      buf = ""
      buf << %Q(<div class="column">) + "\n"

      @column += 1
      buf << "\n" if level > 1
      a_id = %Q(<a id="column-#{@column}"></a>)

      if caption.empty?
        buf << a_id + "\n" if label
      elsif label
        buf << %Q(<h#{level} id="#{normalize_id(label)}">#{a_id}#{compile_inline(caption)}</h#{level}>) + "\n"
      else
        buf << %Q(<h#{level}>#{a_id}#{compile_inline(caption)}</h#{level}>) + "\n"
      end
      buf
    end

    def column_end(_level)
      '</div>' + "\n"
    end

    def xcolumn_begin(level, label, caption)
      buf = ""
      buf << %Q(<div class="xcolumn">) + "\n"
      buf << headline(level, label, caption)
      buf
    end

    def xcolumn_end(_level)
      '</div>' + "\n"
    end

    def ref_begin(level, label, caption)
      buf = ""
      buf << %Q(<div class="reference">)
      buf << headline(level, label, caption)
      buf
    end

    def ref_end(_level)
      '</div>' + "\n"
    end

    def sup_begin(level, label, caption)
      buf = ""
      buf << %Q(<div class="supplement">)
      buf << headline(level, label, caption)
      buf
    end

    def sup_end(_level)
      '</div>' + "\n"
    end

    def captionblock(type, lines, caption)
      buf = ""
      buf << %Q(<div class="#{type}">\n)
      if caption.present?
        buf << %Q(<p class="caption">#{compile_inline(caption)}</p>\n)
      end
      blocked_lines = split_paragraph(lines)
      buf << blocked_lines.join("\n") + "\n"
      buf << '</div>' + "\n"
      buf
    end

    def memo(lines, caption = nil)
      captionblock('memo', lines, caption)
    end

    def tip(lines, caption = nil)
      captionblock('tip', lines, caption)
    end

    def info(lines, caption = nil)
      captionblock('info', lines, caption)
    end

    def planning(lines, caption = nil)
      captionblock('planning', lines, caption)
    end

    def best(lines, caption = nil)
      captionblock('best', lines, caption)
    end

    def important(lines, caption = nil)
      captionblock('important', lines, caption)
    end

    def security(lines, caption = nil)
      captionblock('security', lines, caption)
    end

    def caution(lines, caption = nil)
      captionblock('caution', lines, caption)
    end

    def notice(lines, caption = nil)
      captionblock('notice', lines, caption)
    end

    def warning(lines, caption = nil)
      captionblock('warning', lines, caption)
    end

    def point(lines, caption = nil)
      captionblock('point', lines, caption)
    end

    def shoot(lines, caption = nil)
      captionblock('shoot', lines, caption)
    end

    def box(lines, caption = nil)
      buf = ""
      buf << %Q(<div class="syntax">) + "\n"
      if caption.present?
        buf << %Q(<p class="caption">#{compile_inline(caption)}</p>) + "\n"
      end
      buf << %Q(<pre class="syntax">)
      lines.each do |line|
        buf << detab(line) + "\n"
      end
      buf << '</pre>' + "\n"
      buf << '</div>' + "\n"
      buf
    end

    def note(lines, caption = nil)
      captionblock('note', lines, caption)
    end

    def ul_begin
      '<ul>' + "\n"
    end

    def ul_item_begin(lines)
      "<li>#{lines.join}"
    end

    def ul_item_end
      '</li>' + "\n"
    end

    def ul_end
      '</ul>' + "\n"
    end

    def ol_begin
      buf = ""
      if @ol_num
        buf << %Q(<ol start="#{@ol_num}">) + "\n" # it's OK in HTML5, but not OK in XHTML1.1
        @ol_num = nil
      else
        buf << '<ol>' + "\n"
      end
      buf
    end

    def ol_item(lines, _num)
      "<li>#{lines.join}</li>\n"
    end

    def ol_end
      '</ol>' + "\n"
    end

    def dl_begin
      '<dl>' + "\n"
    end

    def dt(line)
      "<dt>#{line}</dt>\n"
    end

    def dd(lines)
      "<dd>#{lines.join}</dd>\n"
    end

    def dl_end
      '</dl>' + "\n"
    end

    def paragraph(lines)
      buf = ""
      if @noindent
        buf << %Q(<p class="noindent">#{lines.join}</p>\n)
        @noindent = nil
      else
        buf << "<p>#{lines.join}</p>\n"
      end
      buf
    end

    def parasep
      '<br />' + "\n"
    end

    def read(lines)
      buf = ""
      blocked_lines = split_paragraph(lines)
      buf << %Q(<div class="lead">\n#{blocked_lines.join("\n")}\n</div>\n)
      buf
    end

    alias_method :lead, :read

    def list(lines, id, caption, lang = nil)
      buf = ""
      buf << %Q(<div id="#{normalize_id(id)}" class="caption-code">\n)
      begin
        buf << list_header(id, caption, lang)
      rescue KeyError
        error "no such list: #{id}"
      end
      buf << list_body(id, lines, lang)
      buf << '</div>' + "\n"
      buf
    end

    def list_header(id, caption, _lang)
      buf = ""
      if get_chap
        buf << %Q(<p class="caption">#{I18n.t('list')}#{I18n.t('format_number_header', [get_chap, @chapter.list(id).number])}#{I18n.t('caption_prefix')}#{compile_inline(caption)}</p>\n)
      else
        buf << %Q(<p class="caption">#{I18n.t('list')}#{I18n.t('format_number_header_without_chapter', [@chapter.list(id).number])}#{I18n.t('caption_prefix')}#{compile_inline(caption)}</p>\n)
      end
      buf
    end

    def list_body(_id, lines, lang)
      buf = ""
      class_names = ['list']
      lexer = lang
      class_names.push("language-#{lexer}") unless lexer.blank?
      class_names.push('highlight') if highlight?
      buf << %Q(<pre class="#{class_names.join(' ')}">)
      body = lines.inject('') { |i, j| i + detab(j) + "\n" }
      buf << highlight(body: body, lexer: lexer, format: 'html')
      if buf[-1] != "\n"
        buf << "\n"
      end
      buf << '</pre>' + "\n"
      buf
    end

    def source(lines, caption = nil, lang = nil)
      buf << %Q(<div class="source-code">) + "\n"
      buf << source_header(caption)
      buf << source_body(caption, lines, lang)
      buf << '</div>' + "\n"
      buf
    end

    def source_header(caption)
      buf = ""
      if caption.present?
        buf << %Q(<p class="caption">#{compile_inline(caption)}</p>\n)
      end
      buf
    end

    def source_body(_id, lines, lang)
      buf = ""
      buf << %Q(<pre class="source">)
      body = lines.inject('') { |i, j| i + detab(j) + "\n" }
      lexer = lang
      buf << highlight(body: body, lexer: lexer, format: 'html') + "\n"
      buf << '</pre>' + "\n"
      buf
    end

    def listnum(lines, id, caption, lang = nil)
      buf = ""
      buf << %Q(<div id="#{normalize_id(id)}" class="code">) + "\n"
      begin
        buf << list_header(id, caption, lang)
      rescue KeyError
        error "no such list: #{id}"
      end
      buf << listnum_body(lines, lang)
      buf << '</div>' + "\n"
      buf
    end

    def listnum_body(lines, lang)
pp [:listnum, lines]
      buf = ''
      body = lines.inject('') { |i, j| i + detab(j) + "\n" }
      lexer = lang
      first_line_number = line_num
      hs = highlight(body: body, lexer: lexer, format: 'html', linenum: true,
                     options: { linenostart: first_line_number }) + "\n"

      if highlight?
        buf << hs
      else
        class_names = ['list']
        class_names.push("language-#{lang}") unless lang.blank?
        buf << %Q(<pre class="#{class_names.join(' ')}">)
        # class_names.push('highlight') if highlight?
        hs.split("\n").each_with_index do |line, i|
          buf << detab((i + first_line_number).to_s.rjust(2) + ': ' + line + "\n")
        end
        buf << '</pre>' + "\n"
      end
      buf
    end

    def emlist(lines, caption = nil, lang = nil)
      buf = ""
      buf << %Q(<div class="emlist-code">) + "\n"
      if caption.present?
        buf << %Q(<p class="caption">#{compile_inline(caption)}</p>) + "\n"
      end
      class_names = ['emlist']
      class_names.push("language-#{lang}") unless lang.blank?
      class_names.push('highlight') if highlight?
      buf << %Q(<pre class="#{class_names.join(' ')}">)
      body = lines.inject('') { |i, j| i + detab(j) + "\n" }
      lexer = lang
      buf << highlight(body: body, lexer: lexer, format: 'html')
      unless buf[-1] == "\n"
        buf << "\n"
      end
      buf << '</pre>' + "\n"
      buf << '</div>' + "\n"
      buf
    end

    def emlistnum(lines, caption = nil, lang = nil)
      buf = ""
      buf << %Q(<div class="emlistnum-code">) + "\n"
      if caption.present?
        buf << %Q(<p class="caption">#{compile_inline(caption)}</p>) + "\n"
      end

      body = lines.inject('') { |i, j| i + detab(j) + "\n" }
      lexer = lang
      first_line_number = line_num
      hs = highlight(body: body, lexer: lexer, format: 'html', linenum: true,
                     options: { linenostart: first_line_number })
      if highlight?
        buf << hs
      else
        class_names = ['emlist']
        class_names.push("language-#{lang}") unless lang.blank?
        class_names.push('highlight') if highlight?
        buf << %Q(<pre class="#{class_names.join(' ')}">)
        hs.split("\n").each_with_index do |line, i|
          buf << detab((i + first_line_number).to_s.rjust(2) + ': ' + line) + "\n"
        end
        buf << '</pre>' + "\n"
      end

      buf << '</div>' + "\n"
      buf
    end

    def cmd(lines, caption = nil)
      buf = ""
      buf << %Q(<div class="cmd-code">) + "\n"
      if caption.present?
        buf << %Q(<p class="caption">#{compile_inline(caption)}</p>) + "\n"
      end
      buf << %Q(<pre class="cmd">)
      body = lines.inject('') { |i, j| i + detab(j) + "\n" }
      lexer = 'shell-session'
      buf << highlight(body: body, lexer: lexer, format: 'html')
      unless buf[-1] == "\n"
        buf << "\n"
      end
      buf << '</pre>' + "\n"
      buf << '</div>' + "\n"
      buf
    end

    def quotedlist(lines, css_class)
      buf = ""
      buf << %Q(<blockquote><pre class="#{css_class}">)
      lines.each do |line|
        buf << detab(line) + "\n"
      end
      buf << '</pre></blockquote>' + "\n"
      buf
    end
    private :quotedlist

    def quote(lines)
      blocked_lines = split_paragraph(lines)
      %Q(<blockquote>#{blocked_lines.join("\n")}</blockquote>) + "\n"
    end

    def doorquote(lines, ref)
      buf = ""
      blocked_lines = split_paragraph(lines)
      buf << %Q(<blockquote style="text-align:right;">) + "\n"
      buf << blocked_lines.join("\n") + "\n"
      buf << %Q(<p>#{ref}より</p>) + "\n"
      buf << '</blockquote>' + "\n"
      buf
    end

    def talk(lines)
      buf = ""
      buf << %Q(<div class="talk">) + "\n"
      blocked_lines = split_paragraph(lines)
      buf << blocked_lines.join("\n") + "\n"
      buf << '</div>' + "\n"
      buf
    end

    def texequation(lines, id = nil, caption = '')
      buf = ""
      if id
        buf << texequation_header(id, caption)
      end

      buf << texequation_body(lines)

      if id
        buf << '</div>'
      end

      buf
    end

    def texequation_header(id, caption)
      buf = ''
      buf << %Q(<div id="#{normalize_id(id)}" class="caption-equation">\n)
      if get_chap
        buf << %Q(<p class="caption">#{I18n.t('equation')}#{I18n.t('format_number_header', [get_chap, @chapter.equation(id).number])}#{I18n.t('caption_prefix')}#{compile_inline(caption)}</p>\n)
      else
        buf << %Q(<p class="caption">#{I18n.t('equation')}#{I18n.t('format_number_header_without_chapter', [@chapter.equation(id).number])}#{I18n.t('caption_prefix')}#{compile_inline(caption)}</p>\n)
      end

      buf
    end

    def texequation_body(lines)
      buf = ''
      buf << %Q(<div class="equation">\n)
      if @book.config['mathml']
        require 'math_ml'
        require 'math_ml/symbol/character_reference'
        p = MathML::LaTeX::Parser.new(symbol: MathML::Symbol::CharacterReference)
        buf << p.parse(unescape(lines.join("\n")), true) + "\n"
      elsif @book.config['imgmath']
        fontsize = @book.config['imgmath_options']['fontsize'].to_f
        lineheight = @book.config['imgmath_options']['lineheight'].to_f
        math_str = "\\begin{equation*}\n\\fontsize{#{fontsize}}{#{lineheight}}\\selectfont\n#{unescape(lines.join("\n"))}\n\\end{equation*}\n"
        key = Digest::SHA256.hexdigest(math_str)
        math_dir = File.join(@book.config['imagedir'], '_review_math')
        Dir.mkdir(math_dir) unless Dir.exist?(math_dir)
        img_path = File.join(math_dir, "_gen_#{key}.#{@book.config['imgmath_options']['format']}")
        if @book.config.check_version('2', exception: false)
          make_math_image(math_str, img_path)
          buf << %Q(<img src="#{img_path}" />\n)
        else
          defer_math_image(math_str, img_path, key)
          buf << %Q(<img src="#{img_path}" class="math_gen_#{key}" alt="#{escape(lines.join(' '))}" />\n)
        end
      else
        buf << '<pre>'
        buf << escape(lines.join("\n")) + "\n"
        buf << '</pre>' + "\n"
      end
      buf << '</div>' + "\n"
      buf
    end

    def handle_metric(str)
      if str =~ /\Ascale=([\d.]+)\Z/
        return { 'class' => sprintf('width-%03dper', ($1.to_f * 100).round) }
      end

      k, v = str.split('=', 2)
      { k => v.sub(/\A["']/, '').sub(/["']\Z/, '') }
    end

    def result_metric(array)
      attrs = {}
      array.each do |item|
        k = item.keys[0]
        if attrs[k]
          attrs[k] << item[k]
        else
          attrs[k] = [item[k]]
        end
      end
      ' ' + attrs.map { |k, v| %Q(#{k}="#{v.join(' ')}") }.join(' ')
    end

    def image_image(id, caption, metric)
      buf = ""
      metrics = parse_metric('html', metric)
      buf << %Q(<div id="#{normalize_id(id)}" class="image">) + "\n"
      buf << %Q(<img src="#{@chapter.image(id).path.sub(%r{\A\./}, '')}" alt="#{escape(compile_inline(caption))}"#{metrics} />) + "\n"
      buf << image_header(id, caption)
      buf << '</div>' + "\n"
      buf
    end

    def image_dummy(id, caption, lines)
      buf = ""
      warn "image not bound: #{id}"
      buf << %Q(<div id="#{normalize_id(id)}" class="image">) + "\n"
      buf << %Q(<pre class="dummyimage">) + "\n"
      lines.each do |line|
        buf << detab(line) + "\n"
      end
      buf << '</pre>' + "\n"
      buf << image_header(id, caption)
      buf << '</div>' + "\n"
      buf
    end

    def image_header(id, caption)
      buf = ""
      buf << %Q(<p class="caption">) + "\n"
      if get_chap
        buf << %Q(#{I18n.t('image')}#{I18n.t('format_number_header', [get_chap, @chapter.image(id).number])}#{I18n.t('caption_prefix')}#{compile_inline(caption)}) + "\n"
      else
        buf << %Q(#{I18n.t('image')}#{I18n.t('format_number_header_without_chapter', [@chapter.image(id).number])}#{I18n.t('caption_prefix')}#{compile_inline(caption)}) + "\n"
      end
      buf << '</p>' + "\n"
      buf
    end

    def table(lines, id = nil, caption = nil)
      buf = ""
      rows = []
      sepidx = nil
      lines.each_with_index do |line, idx|
        if /\A[\=\-]{12}/ =~ line
          # just ignore
          # error "too many table separator" if sepidx
          sepidx ||= idx
          next
        end
        rows.push(line.strip.split(/\t+/).map { |s| s.sub(/\A\./, '') })
      end
pp [:tbl_rows, lines, rows]
      rows = adjust_n_cols(rows)
      if id
        buf << %Q(<div id="#{normalize_id(id)}" class="table">) + "\n"
      else
        buf << %Q(<div class="table">) + "\n"
      end
      begin
        if caption.present?
          buf << table_header(id, caption)
        end
      rescue KeyError
        error "no such table: #{id}"
      end
      buf << table_begin(rows.first.size)
      return if rows.empty?
      if sepidx
        sepidx.times do
          buf << tr(rows.shift.map { |s| th(s) })
        end
        rows.each do |cols|
          buf << tr(cols.map { |s| td(s) })
        end
      else
        rows.each do |cols|
          h, *cs = *cols
          buf << tr([th(h)] + cs.map { |s| td(s) })
        end
      end
      buf << table_end
      buf << '</div>' + "\n"
      buf
    end

    def table_header(id, caption)
      buf = ""
      if id.nil?
        buf << %Q(<p class="caption">#{compile_inline(caption)}</p>) + "\n"
      elsif get_chap
        buf << %Q(<p class="caption">#{I18n.t('table')}#{I18n.t('format_number_header', [get_chap, @chapter.table(id).number])}#{I18n.t('caption_prefix')}#{compile_inline(caption)}</p>) + "\n"
      else
        buf << %Q(<p class="caption">#{I18n.t('table')}#{I18n.t('format_number_header_without_chapter', [@chapter.table(id).number])}#{I18n.t('caption_prefix')}#{compile_inline(caption)}</p>) + "\n"
      end
      buf
    end

    def table_begin(_ncols)
      '<table>' + "\n"
    end

    def tr(rows)
      "<tr>#{rows.join}</tr>\n"
    end

    def th(str)
      "<th>#{str}</th>"
    end

    def td(str)
      "<td>#{str}</td>"
    end

    def table_end
      '</table>' + "\n"
    end

    def imgtable(lines, id, caption = nil, metric = nil)
      buf = ""
      unless @chapter.image(id).bound?
        warn "image not bound: #{id}"
        buf << image_dummy(id, caption, lines)
        return buf
      end

      buf << %Q(<div id="#{normalize_id(id)}" class="imgtable image">) + "\n"
      begin
        if caption.present?
          buf << table_header(id, caption)
        end
      rescue KeyError
        error "no such table: #{id}"
      end

      buf << imgtable_image(id, caption, metric)

      buf << '</div>' + "\n"
      buf
    end

    def imgtable_image(id, caption, metric)
      metrics = parse_metric('html', metric)
      %Q(<img src="#{@chapter.image(id).path.sub(%r{\A\./}, '')}" alt="#{escape(compile_inline(caption))}"#{metrics} />) + "\n"
    end

    def emtable(lines, caption = nil)
      table(lines, nil, caption)
    end

    def comment(lines, comment = nil)
      return unless @book.config['draft']
      lines ||= []
      lines.unshift escape(comment) unless comment.blank?
      str = lines.join('<br />')
      %Q(<div class="draft-comment">#{escape(str)}</div>) + "\n"
    end

    def footnote(id, str)
      buf = ""
      if @book.config['epubversion'].to_i == 3
        back = ''
        if @book.config['epubmaker'] && @book.config['epubmaker']['back_footnote']
          back = %Q(<a href="#fnb-#{normalize_id(id)}">#{I18n.t('html_footnote_backmark')}</a>)
        end
        # XXX: back link must be located at first of p for Kindle.
        buf << %Q(<div class="footnote" epub:type="footnote" id="fn-#{normalize_id(id)}"><p class="footnote">#{back}#{I18n.t('html_footnote_textmark', @chapter.footnote(id).number)}#{compile_inline(str)}</p></div>)
      else
        buf << %Q(<div class="footnote" id="fn-#{normalize_id(id)}"><p class="footnote">[<a href="#fnb-#{normalize_id(id)}">*#{@chapter.footnote(id).number}</a>] #{compile_inline(str)}</p></div>) + "\n"
      end
      buf
    end

    def indepimage(lines, id, caption = '', metric = nil)
      buf = ""
      metrics = parse_metric('html', metric)
      caption = '' unless caption.present?
      buf << %Q(<div id="#{normalize_id(id)}" class="image">) + "\n"
      begin
        buf << %Q(<img src="#{@chapter.image(id).path.sub(%r{\A\./}, '')}" alt="#{escape(compile_inline(caption))}"#{metrics} />) + "\n"
      rescue
        warn "image not bound: #{id}"
        if lines
          buf << %Q(<pre class="dummyimage">) + "\n"
          lines.each do |line|
            buf << detab(line) + "\n"
          end
          buf << '</pre>' + "\n"
        end
        buf
      end

      if caption.present?
        buf << %Q(<p class="caption">) + "\n"
        buf << %Q(#{I18n.t('numberless_image')}#{I18n.t('caption_prefix')}#{compile_inline(caption)}) + "\n"
        buf << '</p>' + "\n"
      end
      buf << '</div>' + "\n"
      buf
    end

    alias_method :numberlessimage, :indepimage

    def hr
      '<hr />' + "\n"
    end

    def label(id)
      %Q(<a id="#{normalize_id(id)}"></a>) + "\n"
    end

    def blankline
      '<p><br /></p>' + "\n"
    end

    def pagebreak
      %Q(<br class="pagebreak" />) + "\n"
    end

    def bpo(lines)
      buf = ""
      buf << '<bpo>' + "\n"
      lines.each do |line|
        buf << detab(line) + "\n"
      end
      buf << '</bpo>' + "\n"
      buf
    end

    def noindent
      @noindent = true
      ""
    end

    def inline_labelref(idref)
      %Q(<a target='#{escape(idref)}'>「#{I18n.t('label_marker')}#{escape(idref)}」</a>)
    end

    alias_method :inline_ref, :inline_labelref

    def inline_pageref(id)
      error "pageref op is unsupported on this builder: #{id}"
    end

    def inline_chapref(id)
      title = super
      if @book.config['chapterlink']
        %Q(<a href="./#{id}#{extname}">#{title}</a>)
      else
        title
      end
    rescue KeyError
      error "unknown chapter: #{id}"
    end

    def inline_chap(id)
      if @book.config['chapterlink']
        %Q(<a href="./#{id}#{extname}">#{@book.chapter_index.number(id)}</a>)
      else
        @book.chapter_index.number(id)
      end
    rescue KeyError
      error "unknown chapter: #{id}"
    end

    def inline_title(id)
      title = super
      if @book.config['chapterlink']
        %Q(<a href="./#{id}#{extname}">#{title}</a>)
      else
        title
      end
    rescue KeyError
      error "unknown chapter: #{id}"
    end

    def inline_fn(id)
      if @book.config['epubversion'].to_i == 3
        %Q(<a id="fnb-#{normalize_id(id)}" href="#fn-#{normalize_id(id)}" class="noteref" epub:type="noteref">#{I18n.t('html_footnote_refmark', @chapter.footnote(id).number)}</a>)
      else
        %Q(<a id="fnb-#{normalize_id(id)}" href="#fn-#{normalize_id(id)}" class="noteref">*#{@chapter.footnote(id).number}</a>)
      end
    rescue KeyError
      error "unknown footnote: #{id}"
    end

    def compile_ruby(base, ruby)
      if @book.htmlversion == 5
        %Q(<ruby>#{escape(base)}<rp>#{I18n.t('ruby_prefix')}</rp><rt>#{escape(ruby)}</rt><rp>#{I18n.t('ruby_postfix')}</rp></ruby>)
      else
        %Q(<ruby><rb>#{escape(base)}</rb><rp>#{I18n.t('ruby_prefix')}</rp><rt>#{ruby}</rt><rp>#{I18n.t('ruby_postfix')}</rp></ruby>)
      end
    end

    def compile_kw(word, alt)
      %Q(<b class="kw">) +
        if alt
        then escape(word + " (#{alt.strip})")
        else escape(word)
        end +
        "</b><!-- IDX:#{escape_comment(escape(word))} -->"
    end

    def inline_i(str)
      %Q(<i>#{escape(str)}</i>)
    end

    def inline_b(str)
      %Q(<b>#{escape(str)}</b>)
    end

    def inline_ami(str)
      %Q(<span class="ami">#{escape(str)}</span>)
    end

    def inline_bou(str)
      %Q(<span class="bou">#{escape(str)}</span>)
    end

    def inline_tti(str)
      if @book.htmlversion == 5
        %Q(<code class="tt"><i>#{escape(str)}</i></code>)
      else
        %Q(<tt><i>#{escape(str)}</i></tt>)
      end
    end

    def inline_ttb(str)
      if @book.htmlversion == 5
        %Q(<code class="tt"><b>#{escape(str)}</b></code>)
      else
        %Q(<tt><b>#{escape(str)}</b></tt>)
      end
    end

    def inline_dtp(str)
      "<?dtp #{str} ?>"
    end

    def inline_code(str)
      if @book.htmlversion == 5
        %Q(<code class="inline-code tt">#{escape(str)}</code>)
      else
        %Q(<tt class="inline-code">#{escape(str)}</tt>)
      end
    end

    def inline_idx(str)
      %Q(#{escape(str)}<!-- IDX:#{escape_comment(escape(str))} -->)
    end

    def inline_hidx(str)
      %Q(<!-- IDX:#{escape_comment(escape(str))} -->)
    end

    def inline_br(_str)
      '<br />'
    end

    def inline_m(str)
      if @book.config['mathml']
        require 'math_ml'
        require 'math_ml/symbol/character_reference'
        parser = MathML::LaTeX::Parser.new(symbol: MathML::Symbol::CharacterReference)
        %Q(<span class="equation">#{parser.parse(str, nil)}</span>)
      elsif @book.config['imgmath']
        math_str = '$' + str + '$'
        key = Digest::SHA256.hexdigest(str)
        math_dir = File.join(@book.config['imagedir'], '_review_math')
        Dir.mkdir(math_dir) unless Dir.exist?(math_dir)
        img_path = File.join(math_dir, "_gen_#{key}.#{@book.config['imgmath_options']['format']}")
        if @book.config.check_version('2', exception: false)
          make_math_image(math_str, img_path)
          %Q(<span class="equation"><img src="#{img_path}" /></span>)
        else
          defer_math_image(math_str, img_path, key)
          %Q(<span class="equation"><img src="#{img_path}" class="math_gen_#{key}" alt="#{escape(str)}" /></span>)
        end
      else
        %Q(<span class="equation">#{escape(str)}</span>)
      end
    end

    def text(str)
      str
    end

    def bibpaper(lines, id, caption)
      buf = ""
      buf << %Q(<div class="bibpaper">) + "\n"
      buf << bibpaper_header(id, caption)
      buf << bibpaper_bibpaper(id, caption, lines) unless lines.empty?
      buf << '</div>' + "\n"
      buf
    end

    def bibpaper_header(id, caption)
      buf = ""
      buf << %Q(<a id="bib-#{normalize_id(id)}">)
      buf << "[#{@chapter.bibpaper(id).number}]"
      buf << '</a>'
      buf << " #{compile_inline(caption)}\n"
      buf
    end

    def bibpaper_bibpaper(_id, _caption, lines)
      split_paragraph(lines).join
    end

    def inline_bib(id)
      %Q(<a href="#{@book.bib_file.gsub(/\.re\Z/, ".#{@book.config['htmlext']}")}#bib-#{normalize_id(id)}">[#{@chapter.bibpaper(id).number}]</a>)
    rescue KeyError
      error "unknown bib: #{id}"
    end

    def inline_hd_chap(chap, id)
      n = chap.headline_index.number(id)
      if n.present? && chap.number && over_secnolevel?(n)
        str = I18n.t('hd_quote', [n, compile_inline(chap.headline(id).caption)])
      else
        str = I18n.t('hd_quote_without_number', compile_inline(chap.headline(id).caption))
      end
      if @book.config['chapterlink']
        anchor = 'h' + n.gsub('.', '-')
        %Q(<a href="#{chap.id}#{extname}##{anchor}">#{str}</a>)
      else
        str
      end
    rescue KeyError
      error "unknown headline: #{id}"
    end

    def column_label(id, chapter = @chapter)
      num = chapter.column(id).number
      "column-#{num}"
    end
    private :column_label

    def inline_column_chap(chapter, id)
      if @book.config['chapterlink']
        %Q(<a href="\##{column_label(id, chapter)}" class="columnref">#{I18n.t('column', compile_inline(chapter.column(id).caption))}</a>)
      else
        I18n.t('column', compile_inline(chapter.column(id).caption))
      end
    rescue KeyError
      error "unknown column: #{id}"
    end

    def inline_list(id)
      str = super(id)
      chapter, id = extract_chapter_id(id)
      if @book.config['chapterlink']
        %Q(<span class="listref"><a href="./#{chapter.id}#{extname}##{normalize_id(id)}">#{str}</a></span>)
      else
        %Q(<span class="listref">#{str}</span>)
      end
    end

    def inline_table(id)
      str = super(id)
      chapter, id = extract_chapter_id(id)
      if @book.config['chapterlink']
        %Q(<span class="tableref"><a href="./#{chapter.id}#{extname}##{normalize_id(id)}">#{str}</a></span>)
      else
        %Q(<span class="tableref">#{str}</span>)
      end
    end

    def inline_img(id)
      str = super(id)
      chapter, id = extract_chapter_id(id)
      if @book.config['chapterlink']
        %Q(<span class="imgref"><a href="./#{chapter.id}#{extname}##{normalize_id(id)}">#{str}</a></span>)
      else
        %Q(<span class="imgref">#{str}</span>)
      end
    end

    def inline_eq(id)
      str = super(id)
      chapter, id = extract_chapter_id(id)
      if @book.config['chapterlink']
        %Q(<span class="eqref"><a href="./#{chapter.id}#{extname}##{normalize_id(id)}">#{str}</a></span>)
      else
        %Q(<span class="eqref">#{str}</span>)
      end
    end

    def inline_asis(str, tag)
      %Q(<#{tag}>#{escape(str)}</#{tag}>)
    end

    def inline_abbr(str)
      inline_asis(str, 'abbr')
    end

    def inline_acronym(str)
      inline_asis(str, 'acronym')
    end

    def inline_cite(str)
      inline_asis(str, 'cite')
    end

    def inline_dfn(str)
      inline_asis(str, 'dfn')
    end

    def inline_em(str)
      inline_asis(str, 'em')
    end

    def inline_kbd(str)
      inline_asis(str, 'kbd')
    end

    def inline_samp(str)
      inline_asis(str, 'samp')
    end

    def inline_strong(str)
      inline_asis(str, 'strong')
    end

    def inline_var(str)
      inline_asis(str, 'var')
    end

    def inline_big(str)
      inline_asis(str, 'big')
    end

    def inline_small(str)
      inline_asis(str, 'small')
    end

    def inline_sub(str)
      inline_asis(str, 'sub')
    end

    def inline_sup(str)
      inline_asis(str, 'sup')
    end

    def inline_tt(str)
      if @book.htmlversion == 5
        %Q(<code class="tt">#{escape(str)}</code>)
      else
        %Q(<tt>#{escape(str)}</tt>)
      end
    end

    def inline_del(str)
      inline_asis(str, 'del')
    end

    def inline_ins(str)
      inline_asis(str, 'ins')
    end

    def inline_u(str)
      %Q(<u>#{escape(str)}</u>)
    end

    def inline_recipe(str)
      %Q(<span class="recipe">「#{escape(str)}」</span>)
    end

    def inline_icon(id)
      begin
        %Q(<img src="#{@chapter.image(id).path.sub(%r{\A\./}, '')}" alt="[#{id}]" />)
      rescue
        warn "image not bound: #{id}"
        %Q(<pre>missing image: #{id}</pre>)
      end
    end

    def inline_uchar(str)
      %Q(&#x#{str};)
    end

    def inline_comment(str)
      if @book.config['draft']
        %Q(<span class="draft-comment">#{escape(str)}</span>)
      else
        ''
      end
    end

    def inline_tcy(str)
      # 縦中横用のtcy、uprightのCSSスタイルについては電書協ガイドラインを参照
      style = 'tcy'
      if str.size == 1 && str.match(/[[:ascii:]]/)
        style = 'upright'
      end
      %Q(<span class="#{style}">#{escape(str)}</span>)
    end

    def inline_balloon(str)
      %Q(<span class="balloon">#{escape_html(str)}</span>)
    end

    def inline_raw(str)
      super(str)
    end

    def nofunc_text(str)
      escape(str)
    end

    def compile_href(url, label)
      if @book.config['externallink']
        %Q(<a href="#{escape(url)}" class="link">#{label.nil? ? escape(url) : escape(label)}</a>)
      else
        label.nil? ? escape(url) : I18n.t('external_link', [escape(label), escape(url)])
      end
    end

    def flushright(lines)
      split_paragraph(lines).join("\n").gsub('<p>', %Q(<p class="flushright">)) + "\n"
    end

    def centering(lines)
      split_paragraph(lines).join("\n").gsub('<p>', %Q(<p class="center">)) + "\n"
    end

    def image_ext
      'png'
    end

    def olnum(num)
      @ol_num = num.to_i
    end

    def defer_math_image(str, path, key)
      # for Re:VIEW >3
      File.open(File.join(File.dirname(path), '__IMGMATH_BODY__.tex'), 'a+') do |f|
        f.puts str
        f.puts '\\clearpage'
      end
      File.open(File.join(File.dirname(path), '__IMGMATH_BODY__.map'), 'a+') do |f|
        f.puts key
      end
    end

    def make_math_image(str, path, fontsize = 12)
      # Re:VIEW 2 compatibility
      fontsize2 = (fontsize * 1.2).round.to_i
      texsrc = <<-EOB
\\documentclass[12pt]{article}
\\usepackage[utf8]{inputenc}
\\usepackage{amsmath}
\\usepackage{amsthm}
\\usepackage{amssymb}
\\usepackage{amsfonts}
\\usepackage{anyfontsize}
\\usepackage{bm}
\\pagestyle{empty}

\\begin{document}
\\fontsize{#{fontsize}}{#{fontsize2}}\\selectfont #{str}
\\end{document}
      EOB
      Dir.mktmpdir do |tmpdir|
        tex_path = File.join(tmpdir, 'tmpmath.tex')
        dvi_path = File.join(tmpdir, 'tmpmath.dvi')
        File.write(tex_path, texsrc)
        cmd = "latex --interaction=nonstopmode --output-directory=#{tmpdir} #{tex_path} && dvipng -T tight -z9 -o #{path} #{dvi_path}"
        out, status = Open3.capture2e(cmd)
        unless status.success?
          error "latex compile error\n\nError log:\n" + out
        end
      end
    end
  end
end # module ReVIEW
