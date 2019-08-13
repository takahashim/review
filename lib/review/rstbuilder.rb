# Copyright (c) 2008-2017 Minero Aoki, Kenshi Muto
#               2002-2006 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'review/builder'
require 'review/textutils'

module ReVIEW
  #
  # RSTBuilder is a builder for reStructuredText (http://docutils.sourceforge.net/rst.html).
  # reStructuredText is used in Sphinx (http://www.sphinx-doc.org/).
  #
  # If you want to use `ruby`, `del` and `column`, you sould use sphinxcontrib-textstyle
  # package (https://pypi.python.org/pypi/sphinxcontrib-textstyle).
  #
  class RSTBuilder < Builder
    include TextUtils

    %i[ttbold hint maru keytop labelref ref balloon strong].each do |e|
      Compiler.definline(e)
    end
    Compiler.defsingle(:dtp, 1)

    Compiler.defblock(:insn, 1)
    Compiler.defblock(:planning, 0..1)
    Compiler.defblock(:best, 0..1)
    Compiler.defblock(:securty, 0..1)
    Compiler.defblock(:point, 0..1)
    Compiler.defblock(:reference, 0)
    Compiler.defblock(:term, 0)
    Compiler.defblock(:practice, 0)
    Compiler.defblock(:expert, 0)
    Compiler.defblock(:link, 0..1)
    Compiler.defblock(:shoot, 0..1)

    def pre_paragraph
      ''
    end

    def post_paragraph
      ''
    end

    def image_ext
      'png'
    end

    def extname
      '.rst'
    end

    def builder_init_file
      @section = 0
      @subsection = 0
      @subsubsection = 0
      @subsubsubsection = 0
      @blank_seen = true
      @sec_counter = SecCounter.new(5, @chapter)
      @ul_indent = 0
      @ol_indent = 0
      @in_role = false
      @in_table = false
    end
    private :builder_init_file

    def print(s)
      @blank_seen = false
      super
    end
    private :print

    def reset_blank
      @blank_seen = false
    end

    def puts(s)
      @blank_seen = false
      super
    end
    private :puts

    def blank
      ret = @blank_seen ? '' : "\n"
      @blank_seen = true
      ret
    end
    private :blank

    def result
      @output.string
    end

    def headline(level, label, caption)
      buf = ''
      buf << blank
      if label
        buf << ".. _#{label}:\n\n"
      end
      p = '='
      case level
      when 1 then
        unless label
          buf << ".. _#{@chapter.name}:\n\n"
        end
        buf << '=' * caption.size * 2 + "\n"
      when 2 then
        p = '='
      when 3 then
        p = '-'
      when 4 then
        p = '`'
      when 5 then
        p = '~'
      end

      buf << caption + "\n"
      buf << p * caption.size * 2 + "\n\n"
      buf
    end

    def ul_begin
      buf = ''
      buf << blank
      @ul_indent += 1
      buf
    end

    def ul_item(lines)
      '  ' * (@ul_indent - 1) + "* #{lines.join}" + "\n"
    end

    def ul_end
      @ul_indent -= 1
      blank
    end

    def ol_begin
      @ol_indent += 1
      blank
    end

    def ol_item(lines, _num)
      '  ' * (@ol_indent - 1) + "#. #{lines.join}\n"
    end

    def ol_end
      @ol_indent -= 1
      blank
    end

    def dl_begin
      ''
    end

    def dt(line)
      line + "\n"
    end

    def dd(lines)
      split_paragraph(lines).each do |paragraph|
        "  #{paragraph.gsub(/\n/, '')}\n"
      end
    end

    def dl_end
      ''
    end

    def paragraph(lines)
      buf = ''
      pre = ''
      if @in_role
        pre = '   '
      end
      buf << pre + lines.join + "\n\n"
      buf
    end

    def read(lines)
      buf << split_paragraph(lines).map { |line| "  #{line}" }.join + "\n"
      buf << blank
      buf
    end

    alias_method :lead, :read

    def hr
      "----\n"
    end

    def inline_list(id)
      " :numref:`#{id}` "
    end

    def list_header(id, _caption, _lang)
      buf = ''
      buf << ".. _#{id}:\n\n"
      buf
    end

    def list_body(_id, lines, _lang)
      buf = ''
      lines.each do |line|
        buf << '-' + detab(line) + "\n"
      end
      buf
    end

    def base_block(_type, lines, caption = nil)
      buf = ''
      buf << blank
      buf << compile_inline(caption) + "\n" unless caption.nil?
      buf << lines.join("\n") + "\n"
      buf << blank
      buf
    end

    def base_parablock(type, lines, caption = nil)
      buf = ''
      buf << ".. #{type}::\n\n"
      buf << "   #{compile_inline(caption)}\n" unless caption.nil?
      buf << '   ' + split_paragraph(lines).join + "\n"
      buf
    end

    def emlist(lines, caption = nil, lang = nil)
      buf = ''
      buf << blank
      if caption
        buf << caption + "\n\n"
      end
      lang ||= 'none'
      buf << ".. code-block:: #{lang}\n\n"
      lines.each do |line|
        buf << '   ' + detab(line) + "\n"
      end
      buf << blank
      buf
    end

    def emlistnum(lines, caption = nil, lang = nil)
      buf = ''
      buf << blank
      if caption
        buf << caption + "\n\n"
      end
      lang ||= 'none'
      buf << ".. code-block:: #{lang}\n"
      buf << '   :linenos:' + "\n\n"
      lines.each do |line|
        buf << '   ' + detab(line) + "\n"
      end
      reset_blank
      buf << blank
      buf
    end

    def listnum_body(lines, _lang)
      buf = ''
      lines.each_with_index do |line, i|
        buf << (i + 1).to_s.rjust(2) + ": #{line}\n"
      end
      reset_blank
      buf << blank
      buf
    end

    def cmd(lines, _caption = nil)
      buf = ''
      buf << '.. code-block:: bash' + "\n"
      lines.each do |line|
        buf << '   ' + detab(line) + "\n"
      end
      buf
    end

    def quote(lines)
      buf = ''
      buf << blank
      buf << lines.map { |line| "  #{line}" }.join + "\n"
      buf << blank
      buf
    end

    def inline_table(id)
      "表 :numref:`#{id}` "
    end

    def inline_img(id)
      " :numref:`#{id}` "
    end

    def image_image(id, caption, metric)
      chapter, id = extract_chapter_id(id)
      if metric
        scale = metric.split('=')[1].to_f * 100
      end

      buf = ''
      buf << ".. _#{id}:\n\n"
      buf << ".. figure:: images/#{chapter.name}/#{id}.#{image_ext}\n"
      buf << "   :scale:#{scale}%\n" if scale
      buf << "\n"
      buf << "   #{caption}\n\n"
      buf
    end

    def image_dummy(id, caption, lines)
      buf = ''
      chapter, id = extract_chapter_id(id)
      buf << ".. _#{id}:\n\n"
      buf << ".. figure:: images/#{chapter.name}/#{id}.#{image_ext}\n"
      buf << "   #{caption}\n"
      buf << "   #{lines.join}\n"
      buf
    end

    def texequation(lines, id = nil, caption = '')
      buf = ''
      if id
        buf << ".. _#{id}:\n"
      end

      buf << ".. math::\n\n"
      buf << lines.map { |line| "   #{line}" }.join + "\n\n"
      if caption.present?
        buf << "   #{caption}\n\n"
      end
      buf
    end

    def table_header(id, caption)
      buf = ''
      unless id.nil?
        buf << blank
        buf << ".. _#{id}:\n"
      end
      buf << blank
      buf << ".. list-table:: #{compile_inline(caption)}\n"
      buf << '   :header-rows: 1' + "\n\n"
      buf
    end

    def table_begin(ncols)
      ''
    end

    def tr(rows)
      buf = ''
      first = true
      rows.each do |row|
        if first
          buf << "   * - #{row}\n"
          first = false
        else
          buf << "     - #{row}\n"
        end
      end
      buf
    end

    def th(str)
      str
    end

    def td(str)
      str
    end

    def table_end
      reset_blank
      blank
    end

    def emtable(lines, caption = nil)
      table(lines, nil, caption)
    end

    def comment(lines, _comment = nil)
      lines.map { |line| "  .. #{line}" }.join + "\n"
    end

    def footnote(id, str)
      ".. [##{id.sub(' ', '_')}] #{compile_inline(str)}\n"
    end

    def inline_fn(id)
      " [##{id.sub(' ', '_')}]_ "
    end

    def compile_ruby(base, ruby)
      " :ruby:`#{base}`<#{ruby}>`_ "
    end

    def compile_kw(word, alt)
      if alt
        " **#{word}（#{alt.strip}）** "
      else
        " **#{word}** "
      end
    end

    def compile_href(url, label)
      if label.blank?
        label = url
      end
      " `#{label} <#{url}>`_ "
    end

    def inline_sup(str)
      " :superscript:`#{str}` "
    end

    def inline_sub(str)
      " :subscript:`#{str}` "
    end

    def inline_raw(str)
      matched = str.match(/\|(.*?)\|(.*)/)
      if matched
        matched[2].gsub('\\n', "\n")
      else
        str.gsub('\\n', "\n")
      end
    end

    def inline_hint(str)
      # TODO: hint is not default role
      " :hint:`#{str}` "
    end

    def inline_maru(str)
      # TODO: maru is not default role
      " :maru:`#{str}` "
    end

    def inline_idx(str)
      " :index:`#{str}` "
    end

    def inline_hidx(str)
      " :index:`#{str}` "
    end

    def inline_ami(str)
      # TODO: ami is not default role
      " :ami:`#{str}` "
    end

    def inline_i(str)
      " *#{str.gsub('*', '\*')}* "
    end

    def inline_b(str)
      " **#{str.gsub('*', '\*')}** "
    end

    alias_method :inline_strong, :inline_b

    def inline_tt(str)
      " ``#{str}`` "
    end

    alias_method :inline_ttb, :inline_tt  # TODO
    alias_method :inline_tti, :inline_tt  # TODO

    alias_method :inline_ttbold, :inline_ttb

    def inline_u(str)
      " :subscript:`#{str}` "
    end

    def inline_icon(id)
      " :ref:`#{id}` "
    end

    def inline_bou(str)
      # TODO: bou is not default role
      " :bou:`#{str}` "
    end

    def inline_keytop(str)
      # TODO: keytop is not default role
      " :keytop:`#{str}` "
    end

    def inline_balloon(str)
      %Q(\t←#{str.gsub(/@maru\[(\d+)\]/, inline_maru('\1'))})
    end

    def inline_uchar(str)
      [str.to_i(16)].pack('U')
    end

    def inline_comment(str)
      if @book.config['draft']
        str
      else
        ''
      end
    end

    def inline_m(str)
      " :math:`#{str}` "
    end

    def inline_hd_chap(_chap, id)
      " :ref:`#{id}` "
    end

    def noindent
      # TODO
      ''
    end

    def nonum_begin(_level, _label, caption)
      buf << ''
      buf << ".. rubric: #{compile_inline(caption)}\n\n"
      buf
    end

    def nonum_end(level)
      ''
    end

    def common_column_begin(_type, caption)
      buf = ''
      buf << blank
      buf << ".. column:: #{compile_inline(caption)}\n\n"
      @in_role = true
      buf
    end

    def common_column_end(_type)
      @in_role = false
      "\n"
    end

    def column_begin(_level, _label, caption)
      common_column_begin('column', caption)
    end

    def column_end(_level)
      common_column_end('column')
    end

    def xcolumn_begin(_level, _label, caption)
      common_column_begin('xcolumn', caption)
    end

    def xcolumn_end(_level)
      common_column_end('xcolumn')
    end

    def world_begin(_level, _label, caption)
      common_column_begin('world', caption)
    end

    def world_end(_level)
      common_column_end('world')
    end

    def hood_begin(_level, _label, caption)
      common_column_begin('hood', caption)
    end

    def hood_end(_level)
      common_column_end('hood')
    end

    def edition_begin(_level, _label, caption)
      common_column_begin('edition', caption)
    end

    def edition_end(_level)
      common_column_end('edition')
    end

    def insideout_begin(_level, _label, caption)
      common_column_begin('insideout', caption)
    end

    def insideout_end(_level)
      common_column_end('insideout')
    end

    def ref_begin(_level, _label, caption)
      common_column_begin('ref', caption)
    end

    def ref_end(_level)
      common_column_end('ref')
    end

    def sup_begin(_level, _label, caption)
      common_column_begin('sup', caption)
    end

    def sup_end(_level)
      common_column_end('sup')
    end

    def flushright(lines)
      base_parablock 'flushright', lines, nil
    end

    def centering(lines)
      base_parablock 'centering', lines, nil
    end

    def note(lines, caption = nil)
      base_parablock 'note', lines, caption
    end

    def memo(lines, caption = nil)
      base_parablock 'memo', lines, caption
    end

    def tip(lines, caption = nil)
      base_parablock 'tip', lines, caption
    end

    def info(lines, caption = nil)
      base_parablock 'info', lines, caption
    end

    def planning(lines, caption = nil)
      base_parablock 'planning', lines, caption
    end

    def best(lines, caption = nil)
      base_parablock 'best', lines, caption
    end

    def important(lines, caption = nil)
      base_parablock 'important', lines, caption
    end

    def security(lines, caption = nil)
      base_parablock 'security', lines, caption
    end

    def caution(lines, caption = nil)
      base_parablock 'caution', lines, caption
    end

    def term(lines)
      base_parablock 'term', lines, nil
    end

    def link(lines, caption = nil)
      base_parablock 'link', lines, caption
    end

    def notice(lines, caption = nil)
      base_parablock 'notice', lines, caption
    end

    def point(lines, caption = nil)
      base_parablock 'point', lines, caption
    end

    def shoot(lines, caption = nil)
      base_parablock 'shoot', lines, caption
    end

    def reference(lines)
      base_parablock 'reference', lines, nil
    end

    def practice(lines)
      base_parablock 'practice', lines, nil
    end

    def expert(lines)
      base_parablock 'expert', lines, nil
    end

    def insn(lines, caption = nil)
      base_block 'insn', lines, caption
    end

    def warning(lines, caption = nil)
      base_parablock 'warning', lines, caption
    end

    alias_method :box, :insn

    def indepimage(_lines, id, caption = '', _metric = nil)
      chapter, id = extract_chapter_id(id)
      buf = ''
      buf << ".. _#{id}:\n\n"
      buf << ".. figure:: images/#{chapter.name}/#{id}.#{image_ext}\n\n"
      buf << "   #{compile_inline(caption)}\n\n"
      buf
    end

    alias_method :numberlessimage, :indepimage

    def label(id)
      buf = ''
      buf << ".. _#{id}:\n"
      buf
    end

    def dtp(str)
      # FIXME
    end

    def bpo(lines)
      base_block 'bpo', lines, nil
    end

    def inline_dtp(_str)
      ''
    end

    def inline_del(str)
      " :del:`#{str}` "
    end

    def inline_code(str)
      " :code:`#{str}` "
    end

    def inline_br(_str)
      "\n"
    end

    def text(str)
      str
    end

    def inline_chap(id)
      super
    end

    def inline_chapref(id)
      " :numref:`#{id}` "
    end

    def source(lines, caption = nil, _lang = nil)
      base_block 'source', lines, caption
    end

    def inline_ttibold(str)
      # TODO
      " **#{str}** "
    end

    def inline_labelref(idref)
      ''
    end

    alias_method :inline_ref, :inline_labelref

    def inline_pageref(idref)
      " :ref:`#{idref}` "
    end

    def circle_begin(_level, _label, caption)
      puts "・\t#{caption}"
    end

    def circle_end(level)
      ''
    end

    def nofunc_text(str)
      str
    end

    def bib_label(id)
      " [#{id}]_ "
    end
    private :bib_label

    def bibpaper_header(id, caption)
      ''
    end

    def bibpaper_bibpaper(id, caption, lines)
      ".. [#{id}] #{compile_inline(caption)} #{split_paragraph(lines).join}\n"
    end

    def inline_warn(str)
      " :warn:`#{str}` "
    end

    def inline_bib(id)
      " [#{id}]_ "
    end
  end
end # module ReVIEW
