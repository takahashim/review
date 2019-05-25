class NodeList
  include Enumerable
  attr_reader :content
  
  def initialize(*elems)
    if elems
      @content = elems
    else
      @content = []
    end
  end

  def size
    @cotent.size
  end

  def <<(elem)
    @content << elem
    self
  end

  def push(*elem)
    @content.push(*elem)
    self
  end

  def +(elem)
    @content += elem.content
    self
  end

  def to_doc
    @content.map{|item| item.to_doc}.join("")
  end

  def empty?
    @cotent.empty?
  end

  def unshift(elem)
    @content.unshift(elem)
    self
  end

  def each(&block)
    @content.each(&block)
  end

  def to_json
    "{\"_NodeList\":" + @content.to_json + "}"
  end

  def flatten
    cont2 = []
    @content.each do |c|
      if c.kind_of?(NodeList)
        c2 = c.flatten
        cont2.concat(c2.content)
      else
        cont2 << c
      end
    end
    NodeList.new(cont2)
  end
end
