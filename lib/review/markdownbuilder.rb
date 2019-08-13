# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/builder'
require 'review/textutils'
require 'review/htmlutils'

module ReVIEW
  class MARKDOWNBuilder < Builder
    include TextUtils
    include HTMLUtils

    def extname
      '.md'
    end

    def builder_init_file
      @noindent = nil
      @blank_seen = nil
      @ul_indent = 0
      @chapter.book.image_types = %w[.png .jpg .jpeg .gif .svg]
    end
    private :builder_init_file

    def reset_blank
      @blank_seen = false
    end

    def blank
      buf = ''
      unless @blank_seen
        buf << "\n"
      end
      @blank_seen = true
      buf
    end

    def headline(level, _label, caption)
      buf = ''
      buf << blank
      prefix = '#' * level
      reset_blank
      buf << "#{prefix} #{caption}\n"
      buf << blank
      buf
    end

    def quote(lines)
      buf = ''
      buf << blank
      reset_blank
      buf << split_paragraph(lines).map { |line| "> #{line}" }.join("> \n")
      buf << blank
      buf
    end

    def paragraph(lines)
      if @noindent
        @noindent = nil
        reset_blank
        %Q(<p class="noindent">#{lines.join}</p>\n\n)
      else
        reset_blank
        lines.join + "\n\n"
      end
    end

    def noindent
      @noindent = true
      ''
    end

    def list_header(id, caption, lang)
      buf = ''
      if get_chap.nil?
        buf << %Q(リスト#{@chapter.list(id).number} #{compile_inline(caption)}\n\n)
      else
        buf << %Q(リスト#{get_chap}.#{@chapter.list(id).number} #{compile_inline(caption)}\n\n)
      end
      lang ||= ''
      reset_blank
      buf << "```#{lang}\n"
      buf
    end

    def list_body(_id, lines, _lang)
      buf = ''
      lines.each do |line|
        buf << detab(line) + "\n"
      end
      buf << '```' + "\n"
      reset_blank
      buf
    end

    def ul_begin
      ##STDERR.puts "!!!!ul_begin"
      buf = ''
      @ul_indent += 1
      buf
    end

    def ul_item_begin(lines)
      buf = ''
      buf << blank
      ##STDERR.puts "!!!!ul_item_begin(#{lines.join})"
      reset_blank
      buf << '  ' * (@ul_indent - 1) + '* ' + lines.join
      buf
    end

    def ul_item_end
      ##STDERR.puts "!!!!ul_item_end"
      reset_blank
      ''
    end

    def ul_end
      ##STDERR.puts "!!!!ul_end"
      buf = ''
      @ul_indent -= 1
      if @ul_indent == 0
        buf << blank
      end
      reset_blank
      if @ul_indent == 0
        buf << blank
      end
      buf
    end

    def ol_begin
      blank
    end

    def ol_item(lines, num)
      reset_blank
      "#{num}. #{lines.join}\n"
    end

    def ol_end
      blank
    end

    def dl_begin
      reset_blank
      "<dl>\n"
    end

    def dt(line)
      "<dt>#{line}</dt>\n"
    end

    def dd(lines)
      "<dd>#{lines.join}</dd>\n"
    end

    def dl_end
      "</dl>\n"
    end

    def emlist(lines, caption = nil, lang = nil)
      buf = "\n"
      if caption
        buf << caption + "\n\n"
      end
      lang ||= ''
      buf << "```#{lang}\n"
      lines.each do |line|
        buf << detab(line) + "\n"
      end
      buf << "```\n\n"
      buf
    end

    def captionblock(type, lines, caption, _specialstyle = nil)
      buf = ''
      buf << %Q(<div class="#{type}">\n)
      buf << %Q(<p class="caption">#{caption}</p>\n) if caption.present?
      blocked_lines = split_paragraph(lines)
      buf << blocked_lines.join("\n").chomp + "\n"
      buf << "</div>\n"
      reset_blank
      buf
    end

    def hr
      reset_blank
      "----\n"
    end

    def compile_href(url, label)
      if label.blank?
        label = url
      end
      "[#{label}](#{url})"
    end

    def inline_i(str)
      "*#{str.gsub(/\*/, '\*')}*"
    end

    def inline_em(str)
      "*#{str.gsub(/\*/, '\*')}*"
    end

    def inline_b(str)
      "**#{str.gsub(/\*/, '\*')}**"
    end

    def inline_strong(str)
      "**#{str.gsub(/\*/, '\*')}**"
    end

    def inline_code(str)
      "`#{str}`"
    end

    def inline_sub(str)
      "<sub>#{str}</sub>"
    end

    def inline_sup(str)
      "<sup>#{str}</sup>"
    end

    def inline_tt(str)
      "`#{str}`"
    end

    def inline_u(str)
      "<u>#{str}</u>"
    end

    def image_image(id, caption, _metric)
      buf = ''
      buf << "\n"
      buf << "![#{compile_inline(caption)}](#{@chapter.image(id).path.sub(%r{\A\./}, '')})\n"
      buf << "\n"
      buf
    end

    def image_dummy(_id, _caption, lines)
      buf = ''
      buf << lines.join + "\n"
      buf
    end

    def inline_img(id)
      "#{I18n.t('image')}#{@chapter.image(id).number}"
    rescue KeyError
      error "unknown image: #{id}"
    end

    def inline_dtp(str)
      "<!-- DTP:#{str} -->"
    end

    def indepimage(_lines, id, caption = '', _metric = nil)
      buf = ''
      buf << "\n"
      buf << "![#{compile_inline(caption)}](#{@chapter.image(id).path.sub(%r{\A\./}, '')})\n\n"
      buf
    end

    def pagebreak
      "{pagebreak}\n"
    end

    def image_ext
      'jpg'
    end

    def cmd(lines)
      buf = ''
      buf << '```shell-session' + "\n"
      lines.each do |line|
        buf << detab(line) + "\n"
      end
      buf << '```' + "\n"
      buf
    end

    def table(lines, id = nil, caption = nil)
      buf = ''
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
      rows = adjust_n_cols(rows)

      begin
        buf << table_header(id, caption) unless caption.nil?
      rescue KeyError
        error "no such table: #{id}"
      end
      buf << table_begin(rows.first.size)
      if rows.empty?
        return buf
      end
      if sepidx
        sepidx.times do
          buf << tr(rows.shift.map { |s| th(s) })
        end
        buf << table_border(rows.first.size)
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
      buf
    end

    def table_header(id, caption)
      buf = ''
      if id.nil?
        buf << compile_inline(caption) + "\n"
      elsif get_chap
        buf << %Q(#{I18n.t('table')}#{I18n.t('format_number_header', [get_chap, @chapter.table(id).number])}#{I18n.t('caption_prefix')}#{compile_inline(caption)}) + "\n"
      else
        buf << %Q(#{I18n.t('table')}#{I18n.t('format_number_header_without_chapter', [@chapter.table(id).number])}#{I18n.t('caption_prefix')}#{compile_inline(caption)}) + "\n"
      end
      buf << "\n"
      buf
    end

    def table_begin(ncols)
      ''
    end

    def tr(rows)
      "|#{rows.join('|')}|\n"
    end

    def table_border(ncols)
      (0..ncols).map { '|' }.join(':--') + "\n"
    end

    def th(str)
      str
    end

    def td(str)
      str
    end

    def table_end
      "\n"
    end

    def footnote(id, str)
      "[^#{id}]: #{compile_inline(str)}\n\n"
    end

    def inline_fn(id)
      "[^#{id}]"
    end

    def inline_br(_str)
      "\n"
    end

    def nofunc_text(str)
      str
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
          escape_html(word + " (#{alt.strip})")
        else
          escape_html(word)
        end +
        "</b><!-- IDX:#{escape_comment(escape_html(word))} -->"
    end

    def comment(lines, comment = nil)
      unless @book.config['draft']
        return ''
      end
      lines ||= []
      unless comment.blank?
        lines.unshift comment
      end
      str = lines.join('<br />')
      %Q(<div class="red">#{escape(str)}</div>\n)
    end

    def inline_icon(id)
      begin
        "![](#{@chapter.image(id).path.sub(%r{\A\./}, '')})"
      rescue
        warn "image not bound: #{id}"
        %Q(<pre>missing image: #{id}</pre>)
      end
    end

    def inline_comment(str)
      if @book.config['draft']
        %Q(<span class="red">#{escape(str)}</span>)
      else
        ''
      end
    end

    def flushright(lines)
      buf = ''
      buf << %Q(<div class="flushright">) + "\n"
      buf << lines.join + "\n"
      buf << %Q(</div>) + "\n"
      buf
    end
  end
end # module ReVIEW
