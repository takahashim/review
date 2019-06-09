# Copyright (c) 2009-2019 Minero Aoki, Kenshi Muto
# Copyright (c) 2002-2007 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'review/extentions'
require 'review/preprocessor'
require 'review/exception'
require 'review/node'
require 'review/location'
require 'strscan'

module ReVIEW
  class Compiler
    def initialize(strategy)
      @strategy = strategy
    end

    attr_reader :strategy

    def compile(chap)
      @chapter = chap
      @root_ast = []
      @current_content = nil
      do_compile
    end

    class SyntaxElement
      def initialize(name, type, argc, esc, &block)
        @name = name
        @type = type
        @argc_spec = argc
        @esc_patterns = esc
        @checker = block
      end

      attr_reader :name

      def check_args(args)
        unless @argc_spec === args.size
          raise CompileError, "wrong # of parameters (block command //#{@name}, expect #{@argc_spec} but #{args.size})"
        end
        if @checker
          @checker.call(*args)
        end
      end

      def min_argc
        case @argc_spec
        when Range then @argc_spec.begin
        when Integer then @argc_spec
        else
          raise TypeError, "argc_spec is not Range/Integer: #{inspect}"
        end
      end

      def compile_args(args)
        if @esc_patterns
          args.map.with_index do |pattern, i|
            if @esc_patterns[i]
              args[i].__send__("to_#{@esc_patterns[i]}")
            else
              args[i].to_doc
            end
          end
        else
          args.map(&:to_doc)
          ##args.map(&:to_s)
        end
      end

      def block_required?
        @type == :block or @type == :code_block
      end

      def block_allowed?
        %i(block code_block optional optional_code_block).include?(@type)
      end

      def code_block?
        @type == :code_block or @type == :optional_code_block
      end
    end

    SYNTAX = {}

    def self.defblock(name, argc, optional = false, esc = nil, &block)
      defsyntax(name, (optional ? :optional : :block), argc, esc, &block)
    end

    def self.defcodeblock(name, argc, optional = false, esc = nil, &block)
      defsyntax(name, (optional ? :optional_code_block : :code_block), argc, esc, &block)
    end

    def self.defsingle(name, argc, esc = nil, &block)
      defsyntax(name, :line, argc, esc, &block)
    end

    def self.defsyntax(name, type, argc, esc = nil, &block)
      SYNTAX[name] = SyntaxElement.new(name, type, argc, esc, &block)
    end

    def self.definline(name)
      INLINE[name] = InlineSyntaxElement.new(name)
    end

    def syntax_defined?(name)
      SYNTAX.key?(name.to_sym)
    end

    def syntax_descriptor(name)
      SYNTAX[name.to_sym]
    end

    class InlineSyntaxElement
      def initialize(name)
        @name = name
      end

      attr_reader :name
    end

    INLINE = {}

    def inline_defined?(name)
      INLINE.key?(name.to_sym)
    end

    defblock :read, 0
    defblock :lead, 0
    defcodeblock :list, 2..4, false, [:raw, :doc, :raw, :raw]
    defcodeblock :emlist, 0..2, false, [:doc, :raw]
    defcodeblock :cmd, 0..1, false, [:doc]
    defcodeblock :table, 0..2, false, [:raw, :doc]
    defcodeblock :imgtable, 0..2, false, [:raw, :doc]
    defcodeblock :emtable, 0..1, false, [:doc]
    defblock :quote, 0
    defblock :image, 2..3, true
    defcodeblock :source, 0..2, false, [:doc, :raw]
    defcodeblock :listnum, 2..3, false, [:raw, :doc, :raw]
    defcodeblock :emlistnum, 0..2, false, [:doc, :raw]
    defblock :bibpaper, 2..3, true
    defblock :doorquote, 1
    defblock :talk, 0
    defcodeblock :texequation, 0..2
    defblock :graph, 1..3
    defblock :indepimage, 1..3, true, [:raw, :doc, :raw]
    defblock :numberlessimage, 1..3, true, [:raw, :doc, :raw]

    defblock :address, 0
    defblock :blockquote, 0
    defblock :bpo, 0
    defblock :flushright, 0
    defblock :centering, 0
    defblock :note, 0..1
    defblock :memo, 0..1, false, [:doc]
    defblock :info, 0..1
    defblock :important, 0..1
    defblock :caution, 0..1
    defblock :notice, 0..1
    defblock :warning, 0..1
    defblock :tip, 0..1
    defblock :box, 0..1
    defblock :comment, 0..1, true
    defblock :embed, 0..1

    defsingle :footnote, 2, [:raw, :doc]
    defsingle :noindent, 0
    defsingle :blankline, 0
    defsingle :pagebreak, 0
    defsingle :hr, 0
    defsingle :parasep, 0
    defsingle :label, 1, [:raw]
    defsingle :raw, 1, [:raw]
    defsingle :tsize, 1, [:raw]
    defsingle :include, 1, [:raw]
    defsingle :olnum, 1, [:raw]
    defsingle :firstlinenum, 1, [:raw]

    definline :chapref
    definline :chap
    definline :title
    definline :img
    definline :imgref
    definline :icon
    definline :list
    definline :table
    definline :eq
    definline :fn
    definline :kw
    definline :ruby
    definline :bou
    definline :ami
    definline :b
    definline :dtp
    definline :code
    definline :bib
    definline :hd
    definline :href
    definline :recipe
    definline :column
    definline :tcy
    definline :balloon

    definline :abbr
    definline :acronym
    definline :cite
    definline :dfn
    definline :em
    definline :kbd
    definline :q
    definline :samp
    definline :strong
    definline :var
    definline :big
    definline :small
    definline :del
    definline :ins
    definline :sup
    definline :sub
    definline :tt
    definline :i
    definline :tti
    definline :ttb
    definline :u
    definline :raw
    definline :br
    definline :m
    definline :uchar
    definline :idx
    definline :hidx
    definline :comment
    definline :include
    definline :embed
    definline :pageref
    definline :w
    definline :wb

    ## private

    def do_compile
      f = LineInput.new(StringIO.new(@chapter.content))
      @location = Location.new(@chapter.basename, f)
      @strategy.bind(self, @chapter, @location)
      @current_column = nil

      root = ast_init

      while f.next?
        case f.peek
        when /\A\#@/
          f.gets # Nothing to do
        when /\A=+[\[\s\{]/
          @current_content << parse_headline(f.gets)
        when /\A\s+\*/
          @current_content << parse_ulist(f)
        when /\A\s+\d+\./
          @current_content << parse_olist(f)
        when /\A\s*:\s/
          @current_content << parse_dlist(f)
        when %r{\A//\}}
          f.gets
          error 'block end seen but not opened'
        when %r{\A//table\[}
          @current_content << parse_table(f)
        when %r{\A//[a-z]+}
          name, args, lines = read_command(f)
          syntax = syntax_descriptor(name)
          unless syntax
            error "unknown command: //#{name}"
            ## compile_unknown_command(args, lines)
            next
          end
          @current_content << parse_command(syntax, args, lines)
        when %r{\A//}
          line = f.gets
          warn "`//' seen but is not valid command: #{line.strip.inspect}"
          if block_open?(line)
            warn 'skipping block...'
            read_block(f, false)
          end
        else
          if f.peek.strip.empty?
            f.gets
            next
          end
          @current_content << read_paragraph(f)
        end
      end

      ast = ast_convert(root)
      ast
    end

    def ast_init
      root_ast = DocumentNode.new(self, 0, [])
      @current_content = root_ast.content
      root_ast
    end

    def ast_convert(ast)
      new_ast = convert_column(ast)
      if $DEBUG
        File.open("review-dump.json","w") do |f|
          f.write(ast.to_json)
        end
      end
      new_ast.to_doc
    end

    def position
      @location.to_s
    end

    def parse_headline(line)
      m = /\A(=+)(?:\[(.+?)\])?(?:\{(.+?)\})?(.*)/.match(line)
      level = m[1].size
      tag = m[2]
      label = m[3]
      caption = text(m[4].strip)
      HeadlineNode.new(self, position, level, tag, label, caption)
    end

    def compile_column(level, label, caption, content)
pp [:compile_column, caption, content]
      buf = ""
      buf << @strategy.__send__("column_begin", level, label, caption)
      buf << content.to_doc
      buf << @strategy.__send__("column_end", level)
      buf
    end

    def compile_headline(level, tag, label, caption)
      buf = ""
      caption ||= ""
      caption.strip!
      index = level - 1
      buf << @strategy.headline(level, label, caption)
      buf
    end

    def convert_column(doc)
      content = doc.content
      new_content = NodeList.new
      current_content = new_content
      content.each do |elem|
        if elem.kind_of?(ReVIEW::HeadlineNode) && elem.cmd && elem.cmd == "column"
          flush_column(new_content)
          current_content = NodeList.new
          @current_column = ReVIEW::ColumnNode.new(elem.compiler, elem.position, elem.level,
                                                  elem.label, elem.content, current_content)
          next
        elsif elem.kind_of?(ReVIEW::HeadlineNode) && elem.cmd && elem.cmd =~ %r|^/|
          cmd_name = elem.cmd[1..-1]
          if cmd_name != "column"
            raise ReVIEW::CompileError, "#{cmd_name} is not opened."
          end
          flush_column(new_content)
          current_content = new_content
          next
        elsif elem.kind_of?(ReVIEW::HeadlineNode) && @current_column && elem.level <= @current_column.level
          flush_column(new_content)
          current_content = new_content
        end
        current_content << elem
      end
      flush_column(new_content)
      doc.content = new_content
      doc
    end

    def flush_column(new_content)
      if @current_column
        new_content << @current_column
        @current_column = nil
      end
    end

#    def comment(text)
#      @strategy.comment(text)
#    end

    def parse_ulist(f)
      current_ulist = nil
      ulist_stack = []
      level = 0
      f.while_match(/\A\s+\*|\A\#@/) do |line|
        next if line =~ /\A\#@/

        buf = text(line.sub(/\*+/, '').strip)
        f.while_match(/\A\s+(?!\*)\S/) do |cont|
          buf.push(*text(cont.strip))
        end

        line =~ /\A\s+(\*+)/
        current_level = $1.size
        if level == current_level
          elem = UlistElementNode.new(self, position, level, buf)
          current_ulist.add_element(elem)
        elsif level < current_level # down
          level_diff = current_level - level
          level = current_level
          (1..(level_diff - 1)).to_a.reverse_each do |i|
            elem = UlistElementNode.new(self, position, level - i, [])
            ulist = UlistNode.new(self, position, [elem])
            if current_ulist
              current_ulist.add_ulist(ulist)
            end
            ulist_stack << ulist
            current_ulist = ulist_stack.last
          end
          elem = UlistElementNode.new(self, position, level, buf)
          ulist = UlistNode.new(self, position, [elem])
          if current_ulist
            current_ulist.add_ulist(ulist)
          end
          ulist_stack << ulist
          current_ulist = ulist_stack.last
        elsif level > current_level # up
          level_diff = level - current_level
          level = current_level
          (1..level_diff).to_a.reverse_each do |i|
            ulist_stack.pop
          end
          current_ulist = ulist_stack.last
          elem = UlistElementNode.new(self, position, level, buf)
          current_ulist.add_element(elem)
        end
      end

      if ulist_stack.size > 0
        current_ulist = ulist_stack.first
      end

pp [:ulist, current_ulist]
      current_ulist
    end

    def parse_olist(f)
      olist = OlistNode.new(self, position, [])
      f.while_match(/\A\s+\d+\.|\A\#@/) do |line|
        next if line =~ /\A\#@/

        num = line.match(/(\d+)\./)[1]
        buf = text(line.sub(/\d+\./, '').strip)
        f.while_match(/\A\s+(?!\d+\.)\S/) do |cont|
          buf.push(*text(cont.strip))
        end
        olist.content << OlistElementNode.new(self, position, num, buf)
      end
      olist
    end

    def parse_dlist(f)
      dlist = DlistNode.new(self, position, [])
      while /\A\s*:/ =~ f.peek
        dt = text(f.gets.sub(/\A\s*:/, '').strip)
        dd = []
        f.break(/\A(\S|\s*:|\s+\d+\.\s|\s+\*\s)/).each do |line|
          dd.push(*text(line.strip))
        end
        dlist.content << DlistElementNode.new(self, position, dt, dd)
        f.skip_blank_lines
        f.skip_comment_lines
      end
      dlist
    end

    def compile_ulist(content)
      buf = ""
      buf << @strategy.ul_begin
      content.each do |element|
        buf << element.to_doc
      end
      buf << @strategy.ul_end
      buf
    end

    def compile_ul_elem(content)
      buf = ''
      buf << @strategy.ul_item_begin([])
      content.each do |element|
        buf << element.to_doc
      end
      buf << @strategy.ul_item_end
      buf
    end

=begin
    def compile_ulist(content)
      buf0 = ""
      level = 0
      content.each do |element|
        current_level = element.level
        buf = element.to_doc
        if level == current_level
          buf0 << @strategy.ul_item_end
          # body
          buf0 << @strategy.ul_item_begin([buf])
        elsif level < current_level # down
          level_diff = current_level - level
          level = current_level
          (1..(level_diff - 1)).to_a.reverse_each do |i|
            buf0 << @strategy.ul_begin{i}
            buf0 << @strategy.ul_item_begin([])
          end
          buf0 << @strategy.ul_begin{level}
          buf0 << @strategy.ul_item_begin([buf])
        elsif level > current_level # up
          level_diff = level - current_level
          level = current_level
          (1..level_diff).to_a.reverse_each do |i|
            buf0 << @strategy.ul_item_end
            buf0 << @strategy.ul_end{level + i}
          end
          buf0 << @strategy.ul_item_end
          # body
          buf0 << @strategy.ul_item_begin([buf])
        end
      end

      (1..level).to_a.reverse_each do |i|
        buf0 << @strategy.ul_item_end
        buf0 << @strategy.ul_end{i}
      end
      buf0
    end
=end

    def compile_olist(content)
      buf0 = ""
      buf0 << @strategy.ol_begin
      content.each do |element|
        ## XXX 1st arg should be String, not Array
        buf0 << @strategy.ol_item(element.to_doc.split(/\n/), element.num)
      end
      buf0 << @strategy.ol_end
      buf0
    end

    def compile_dlist(content)
      buf = ""
      buf << @strategy.dl_begin
      content.each do |element|
        buf << @strategy.dt(element.text.to_doc)
        buf << @strategy.dd(element.content.map{|s| s.to_doc})
      end
      buf << @strategy.dl_end
      buf
    end

    def read_paragraph(f)
      buf = []
      f.until_match(%r{\A//|\A\#@}) do |line|
        break if line.strip.empty?
        buf.push(*text(line.sub(/^(\t+)\s*/) { |m| '<!ESCAPETAB!>' * m.size }.strip.gsub('<!ESCAPETAB!>', "\t")))
      end
      ParagraphNode.new(self, position, buf)
    end

    def parse_table(f)
      # lines, id = nil, caption = nil
      name, args, lines = read_command(f)
      syntax = syntax_descriptor(name)
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

    def compile_paragraph(buf)
      @strategy.paragraph(buf)
    end

    def read_command(f)
      line = f.gets
      name = line.slice(/[a-z]+/).to_sym
      ignore_inline = (name == :embed)
      args = parse_args(line.sub(%r{\A//[a-z]+}, '').rstrip.chomp('{'), name)
pp [:parsed_args, args]
      @strategy.doc_status[name] = true
      lines = block_open?(line) ? read_block(f, ignore_inline) : nil
      @strategy.doc_status[name] = nil
      [name, args, lines]
    end

    def block_open?(line)
      line.rstrip[-1, 1] == '{'
    end

    def read_block(f, ignore_inline)
      head = f.lineno
      buf = []
      f.until_match(%r{\A//\}}) do |line|
        if ignore_inline
          buf.push line
        elsif line !~ /\A\#@/
          buf.push(line)
        end
      end
      unless %r{\A//\}} =~ f.peek
        error "unexpected EOF (block begins at: #{head})"
        return buf
      end
      f.gets # discard terminator
pp [:read_block, buf]
      if ignore_inline
        buf
      else
        buf.join("")
      end
    end

    def parse_args(str, _name = nil)
      return [] if str.empty?
      scanner = StringScanner.new(str)
      words = []
      while word = scanner.scan(/(\[\]|\[.*?[^\\]\])/)
        w2 = word[1..-2].gsub(/\\(.)/) do
          ch = $1
          [']', '\\'].include?(ch) ? ch : '\\' + ch
        end
        words << w2
      end
      unless scanner.eos?
        error "argument syntax error: #{scanner.rest} in #{str.inspect}"
        return []
      end
      words
    end

    def parse_command(syntax, args, lines)
      if !syntax || (!@strategy.respond_to?(syntax.name) && !@strategy.respond_to?("node_#{syntax.name}"))
        error "strategy does not support command: //#{syntax.name}"
        return
      end
      begin
        syntax.check_args args
      rescue CompileError => e
        error e.message
        args = ['(NoArgument)'] * syntax.min_argc
      end
      if syntax.block_allowed?
        if syntax.name == :embed
          return EmbedNode.new(self, @strategy.target_name, position, lines)
        end
        content = parse_block_content(lines, syntax.code_block?)
        if syntax.code_block?
          CodeBlockElementNode.new(self, position, syntax.name, args, content)
        else
          BlockElementNode.new(self, position, syntax.name, args, content)
        end
      else
        if lines
          error "block is not allowed for command //#{syntax.name}; ignore"
        end
        if syntax.code_block?
          CodeBlockElementNode.new(self, position, syntax.name, args, nil)
        else
          BlockElementNode.new(self, position, syntax.name, args, nil)
        end
      end
    end

    def parse_block_content(lines, code_block)
      unless lines
        return lines
      end
pp [:lines, lines]
      if code_block
        return NodeList.new(text(lines))
      end
      buf = []
      list = NodeList.new
      lines.each do |line|
        if line.chomp.empty?
          list << text(buf.join + line)
          buf = []
        else
          buf << line
        end
      end
      unless buf.empty?
        list << text(buf.join)
      end
pp [:parse_block_content, list]
      list
    end

    def compile_command(name, args, lines, node)
      syntax = syntax_descriptor(name)
      if !syntax || (!@strategy.respond_to?(syntax.name) && !@strategy.respond_to?("node_#{syntax.name}"))
        error "strategy does not support command: //#{name}"
        return
      end
      begin
        syntax.check_args args
      rescue ReVIEW::CompileError => err
        error err.message
        args = ['(NoArgument)'] * syntax.min_argc
      end
      if syntax.block_allowed?
        compile_block(syntax, args, lines, node)
      else
        if lines
          error "block is not allowed for command //#{syntax.name}; ignore"
        end
        compile_single(syntax, args, node)
      end
    end

    def compile_block(syntax, args, lines, node)
pp [:compile_block, lines]
      node_name = "node_#{syntax.name}".to_sym
      if @strategy.respond_to?(node_name)
        @strategy.__send__(node_name, node)
      else
        p_args = args.map{|arg| text(arg)}
        args_conv = syntax.compile_args(p_args)
pp [:args_conv, args_conv]
        @strategy.__send__(syntax.name, (lines || default_block(syntax)), *args_conv)
      end
    end

    def default_block(syntax)
      if syntax.block_required?
        error "block is required for //#{syntax.name}; use empty block"
      end
      []
    end

    def compile_single(syntax, args, node)
      node_name = "node_#{syntax.name}".to_sym
      if @strategy.respond_to?(node_name)
        @strategy.__send__(node_name, node)
      else
        p_args = args.map{|arg| text(arg)}
        args_conv = syntax.compile_args(p_args)
        @strategy.__send__(syntax.name, *args_conv)
      end
    end

    def replace_fence(str)
      str.gsub(/@<(\w+)>([$|])(.+?)(\2)/) do
        op = $1
        arg = $3
        if arg =~ /[\x01\x02\x03\x04]/
          error "invalid character in '#{str}'"
        end
        replaced = arg.gsub('@', "\x01").gsub('\\', "\x02").gsub('{', "\x03").gsub('}', "\x04")
        "@<#{op}>{#{replaced}}"
      end
    end

    def revert_replace_fence(str)
      str.gsub("\x01", '@').gsub("\x02", '\\').gsub("\x03", '{').gsub("\x04", '}')
    end

    def text(str)
      return NodeList.new if str.empty?
      words = replace_fence(str).split(/(@<\w+>\{(?:[^\}\\]|\\.)*?\})/, -1)
      words.each do |w|
        if w.scan(/@<\w+>/).size > 1 && !/\A@<raw>/.match(w)
          error "`@<xxx>' seen but is not valid inline op: #{w}"
        end
      end
      result = NodeList.new(TextNode.new(self, position, revert_replace_fence(words.shift)))
      until words.empty?
        result << parse_inline(revert_replace_fence(words.shift.gsub(/\\\}/, '}').gsub(/\\\\/, '\\')))
        result << TextNode.new(self, position, revert_replace_fence(words.shift))
      end
      result
    rescue => e
      error e.message
    end
    public :text # called from strategy

    def parse_inline(str)
      op, arg = /\A@<(\w+)>\{(.*?)\}\z/.match(str).captures
      unless inline_defined?(op)
        raise CompileError, "no such inline op: #{op}"
      end
      if !@strategy.respond_to?("inline_#{op}") && !@strategy.respond_to?("node_inline_#{op}")
        raise "strategy does not support inline op: @<#{op}>"
      end
      i_node = InlineElementNode.new(self, position, op, [arg])
      i_node
    rescue => e
      error e.message
      TextNode.new(self, position, str)
    end

    def compile_inline(op, args)
      if @strategy.respond_to?("node_inline_#{op}")
        return @strategy.__send__("node_inline_#{op}", args)
      end
      if !args
        @strategy.__send__("inline_#{op}", "")
      else
        ## @strategy.__send__("inline_#{op}", *(args.map(&:to_doc)))
        @strategy.__send__("inline_#{op}", *(args.map(&:to_s)))
      end
#    rescue => e
#      error e.message
    end

    def compile_text(text)
      @strategy.nofunc_text(text)
    end

    def compile_raw(builders, content)
      c = @strategy.class.to_s.gsub(/ReVIEW::/, '').gsub(/Builder/, '').downcase
      if !builders || builders.include?(c)
        content.gsub("\\n", "\n")
      else
        ""
      end
    end

    def compile_embed(builders, content)
      c = @strategy.class.to_s.gsub(/ReVIEW::/, '').gsub(/Builder/, '').downcase
      if !builders || builders.include?(c)
        content
      else
        ""
      end
    end

    def warn(msg)
      @strategy.warn msg
    end

    def error(msg)
      @strategy.error msg
    end
  end
end # module ReVIEW
