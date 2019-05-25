require 'json'
require 'review/nodelist'

module ReVIEW
  class Node
    attr_accessor :content

    def to_raw
      to_s_by(:to_raw)
    end

    def to_doc
      to_s_by(:to_doc)
    end

    def to_s_by(meth)
      if content.kind_of? String
        @content
      elsif content.nil?
        nil
      elsif !content.kind_of? Array
        @content.__send__(meth)
      else
        ##@content.map(&meth).join("")
        @content.map{|o| o.__send__(meth)}.join("")
      end
    end

    def to_json(*args)
      if content.kind_of? String
        val = '"'+@content.gsub(/\"/,'\\"').gsub(/\n/,'\\n')+'"'
      elsif content.nil?
        val = "null"
      elsif !content.kind_of? Array
        val = @content.to_json
      else
        val = "["+@content.map(&:to_json).join(",")+"]"
      end
      '{"ruleName":"' + self.class.to_s.sub(/ReVIEW::/,"").sub(/Node$/,"") + '",' +
        "\"line\":#{position.to_s}," +
        '"childNodes":' + val +
        '}'
    end

    def inspect
      self.to_json
    end

  end

  class HeadlineNode < Node
    def initialize(compiler, position, level, cmd, label, content)
      @compiler = compiler
      @position = position
      @level = level
      @cmd = cmd
      @label = label
      @content = content
    end
    attr_reader :compiler
    attr_reader :position
    attr_reader :level
    attr_reader :cmd
    attr_reader :label
    attr_reader :content

    def to_doc
      content_str = super
      cmd = @cmd ? @cmd.to_doc : nil
      label = @label
      @compiler.compile_headline(@level, cmd, label, content_str)
    end

    def to_json
      '{"ruleName":"' + self.class.to_s.sub(/ReVIEW::/,"").sub(/Node$/,"") + '",' +
        %Q|"cmd":"#{@cmd.to_json}",|+
        %Q|"label":"#{@label.to_json}",|+
        "\"line\":#{position.to_s}," +
        '"childNodes":' + @content.to_json + '}'
    end
  end

  class ParagraphNode < Node
    def initialize(compiler, position, content)
      @compiler = compiler
      @position = position
      @content = content
    end
    attr_reader :compiler
    attr_reader :position
    attr_reader :content

    def to_doc
      #content = @content.map(&:to_doc)
      content = super.split(/\n/)
      @compiler.compile_paragraph(content)
    end
  end

  class BlockElementNode < Node

    def initialize(compiler, position, name, args, content)
      @compiler = compiler
      @position = position
      @name = name
      @args = args
      @content = content
    end
    attr_reader :compiler
    attr_reader :position
    attr_reader :name
    attr_reader :args
    attr_reader :content

    def to_doc
      # content_str = super
      ## args = @args.map(&:to_doc)
      if @content
        content_lines = @content.map(&:to_doc)
      else
        content_lines = nil
      end
      @compiler.compile_command(@name, @args, content_lines, self)
    end

    def parse_args(*patterns)
      patterns.map.with_index do |pattern, i|
        if @args[i]
          @args[i].__send__("to_#{pattern}")
        else
          nil
        end
      end
    end
  end

  class CodeBlockElementNode < Node

    def initialize(compiler, position, name, args, content)
      @compiler = compiler
      @position = position
      @name = name
      @args = args
      @content = content
    end
    attr_reader :compiler
    attr_reader :position
    attr_reader :name
    attr_reader :args
    attr_reader :content

    def to_doc
      # content_str = super
      ## args = @args.map(&:to_doc)
      if @content
        content_lines = raw_lines
      else
        content_lines = nil
      end
      @compiler.compile_command(@name, @args, content_lines, self)
    end

    def parse_args(*patterns)
      patterns.map.with_index do |pattern, i|
        if @args[i]
          @args[i].__send__("to_#{pattern}")
        else
          nil
        end
      end
    end

    def raw_lines
      self.content.to_doc.split(/\n/)
    end
  end


  class InlineElementNode < Node
    def initialize(compiler, position, symbol, content)
      @compiler = compiler
      @position = position
      @symbol = symbol
      @content = content
    end
    attr_reader :compiler
    attr_reader :position
    attr_reader :symbol
    attr_reader :content

    def to_raw
      content_str = super
      "@<#{@symbol}>{#{content_str}}"
    end

    def to_doc
      #content_str = super
      @compiler.compile_inline(@symbol, @content)
    end

    def to_json
      '{"ruleName":"' + self.class.to_s.sub(/ReVIEW::/,"").sub(/Node$/,"") + '",' +
        %Q|"symbol":"#{@symbol}",| +
        "\"line\":#{position.to_s}," +
        (@concat ? '"childNodes":[' + @content.map(&:to_json).join(",") + ']' : '"childNodes":[]') + '}'
    end
  end

  class ComplexInlineElementNode < Node
    def initialize(compiler, position, symbol, content)
      @compiler = compiler
      @position = position
      @symbol = symbol
      @content = content
    end
    attr_reader :compiler
    attr_reader :position
    attr_reader :symbol
    attr_reader :content

    def to_raw
      content_str = super
      "@<#{@symbol}>{#{content_str}}"
    end

    def to_doc
      #content_str = super
      @compiler.compile_inline(@symbol, @content)
    end

    def to_json
      '{"ruleName":"' + self.class.to_s.sub(/ReVIEW::/,"").sub(/Node$/,"") + '",' +
        %Q|"symbol":"#{@symbol}",| +
        "\"line\":#{position.to_s}," +
        '"childNodes":[' + @content.map(&:to_json).join(",") + ']}'
    end
  end

  class InlineElementContentNode < Node
    def initialize(compiler, position, content)
      @compiler = compiler
      @position = position
      @content = content
    end
    attr_reader :compiler
    attr_reader :position
    attr_reader :content
  end

  class ComplexInlineElementContentNode < Node
    def initialize(compiler, position, content)
      @compiler = compiler
      @position = position
      @content = content
    end
    attr_reader :compiler
    attr_reader :position
    attr_reader :content
  end

  class TextNode < Node
    def initialize(compiler, position, content)
      @compiler = compiler
      @position = position
      @content = content
    end
    attr_reader :compiler
    attr_reader :position
    attr_reader :content

    def to_raw
      content_str = super
      content_str.to_s
    end

    def to_doc
      content_str = super
      @compiler.compile_text(content_str)
    end

    def to_json(*args)
      val = '"'+@content.gsub(/\"/,'\\"').gsub(/\n/,'\\n')+'"'
      '{"ruleName":"' + self.class.to_s.sub(/ReVIEW::/,"").sub(/Node$/,"") + '",' +
        "\"line\":#{position.to_s}," +
        '"text":' + val + '}'
    end
  end

  class NewLineNode < Node
    def initialize(compiler, position, content)
      @compiler = compiler
      @position = position
      @content = content
    end
    attr_reader :compiler
    attr_reader :position
    attr_reader :content

    def to_doc
      ""
    end
  end

  class RawNode < Node
    def initialize(compiler, builder, position, content)
      @compiler = compiler
      @builder = builder
      @position = position
      @content = content
    end
    attr_reader :compiler
    attr_reader :builder
    attr_reader :position
    attr_reader :content

    def to_doc
      @compiler.compile_raw(@builder, @content.join(""))
    end
  end

  class BracketArgNode < Node
      def initialize(compiler, position, content)
        @compiler = compiler
        @position = position
        @content = content
      end
      attr_reader :compiler
      attr_reader :position
      attr_reader :content
  end

  class BraceArgNode < Node
  end

  class SinglelineCommentNode < Node
    def initialize(compiler, position, content)
      @compiler = compiler
      @position = position
      @content = content
    end
    attr_reader :compiler
    attr_reader :position
    attr_reader :content

    def to_doc
      ""
    end
  end

  class SinglelineContentNode < Node
    def initialize(compiler, position, content)
      @compiler = compiler
      @position = position
      @content = content
    end
    attr_reader :compiler
    attr_reader :position
    attr_reader :content
  end

  class UlistNode < Node
    def initialize(compiler, position, content)
      @compiler = compiler
      @position = position
      @content = content
    end
    attr_reader :compiler
    attr_reader :position
    attr_reader :content

    def to_doc
      @compiler.compile_ulist(@content)
    end

    def add_element(elem)
      self.content << elem
    end

    def add_ulist(ulist)
      last_elem = self.content.last
      last_elem.content << ulist
    end
  end

  class UlistElementNode < Node
    def initialize(compiler, position, level, content)
      @compiler = compiler
      @position = position
      @level = level
      @content = content
    end
    attr_reader :compiler
    attr_reader :position
    attr_reader :level
    attr_reader :content

    def level=(level)
      @level = level
    end

    def to_doc
      @content.map(&:to_doc).join("")
    end

    def concat(elem)
      @content << elem
    end
  end

  class OlistNode < Node
    def initialize(compiler, position, content)
      @compiler = compiler
      @position = position
      @content = content
    end
    attr_reader :compiler
    attr_reader :position
    attr_reader :content

    def to_doc
      @compiler.compile_olist(@content)
    end
  end

  class OlistElementNode < Node
    def initialize(compiler, position, num, content)
      @compiler = compiler
      @position = position
      @num = num
      @content = content
    end
    attr_reader :compiler
    attr_reader :position
    attr_reader :num
    attr_reader :content

    def num=(num)
      @num = num
    end

    def to_doc
      @content.map(&:to_doc).join("")
    end

    def concat(elem)
      @content << elem
    end
  end

  class DlistNode < Node
    def initialize(compiler, position, content)
      @compiler = compiler
      @position = position
      @content = content
    end
    attr_reader :compiler
    attr_reader :position
    attr_reader :content

    def to_doc
      @compiler.compile_dlist(@content)
    end
  end

  class DlistElementNode < Node
    def initialize(compiler, position, text, content)
      @compiler = compiler
      @position = position
      @text = text
      @content = content
    end
    attr_reader :compiler
    attr_reader :position
    attr_reader :text
    attr_reader :content

    def to_doc
      @content.map(&:to_doc).join("")
    end
  end

  class DocumentNode < Node
    def initialize(compiler, position, content)
      @compiler = compiler
      @position = position
      @content = content
    end
    attr_reader :compiler
    attr_reader :position
    attr_reader :content
  end

  class ColumnNode < Node
    def initialize(compiler, position, level, label, caption, content)
      @compiler = compiler
      @position = position
      @level = level
      @label = label
      @caption = caption
      @content = content
    end
    attr_reader :compiler
    attr_reader :position
    attr_reader :level
    attr_reader :label
    attr_reader :caption
    attr_reader :content

    def to_doc
      level = @level
      label = @label
      caption = @caption ? @caption.to_doc : nil
      @compiler.compile_column(level, label, caption, @content)
    end
  end

  ## -----
  class BraceNode < Node
    def initialize(compiler, position, content)
      @compiler = compiler
      @position = position
      @content = content
    end
    attr_reader :compiler
    attr_reader :position
    attr_reader :content
  end

end
