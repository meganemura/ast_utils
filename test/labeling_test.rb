require "test_helper"

class LabelingTest < Minitest::Test
  Labeling = ASTUtils::Labeling

  include TestHelper

  def parse(source)
    Parser::Ruby25.parse(source)
  end

  def test_lvar
    node = parse(<<-EOR)
x = 1
x
    EOR

    labeled = Labeling.translate(node: node)
    assert_equal dig(labeled, 0, 0), dig(labeled, 1, 0)
  end

  def test_def
    node = parse(<<-EOR)
def f(a, b=2, *c, d:, e: :e, **f, &g)
  a
  b
  c
  d
  e
  f
  g
end
    EOR

    labeled = Labeling.translate(node: node)

    assert_equal dig(labeled, 1, 0, 0), dig(labeled, 2, 0, 0), "a"
    assert_equal dig(labeled, 1, 1, 0), dig(labeled, 2, 1, 0), "b"
    assert_equal dig(labeled, 1, 2, 0), dig(labeled, 2, 2, 0), "c"
    assert_equal dig(labeled, 1, 3, 0), dig(labeled, 2, 3, 0), "d"
    assert_equal dig(labeled, 1, 4, 0), dig(labeled, 2, 4, 0), "e"
    assert_equal dig(labeled, 1, 5, 0), dig(labeled, 2, 5, 0), "f"
    assert_equal dig(labeled, 1, 6, 0), dig(labeled, 2, 6, 0), "g"
  end

  def test_block
    node = parse(<<-EOR)
x = 0
y = 1
a = 2
c = 3
tap do |y, (a,b), z = 2|
  x
  y
  a
  b
  c
end
    EOR

    labeled = Labeling.translate(node: node)

    assert_equal dig(labeled, 0, 0), dig(labeled, 4, 2, 0, 0), "Refers x in enclosing block"
    assert_equal dig(labeled, 4, 1, 0, 0), dig(labeled, 4, 2, 1, 0), "Referes block parameter y"
    refute_equal dig(labeled, 1, 0), dig(labeled, 4, 1, 0, 0), "Block param y is different from y in enclosing block"

    refute_equal dig(labeled, 4, 1, 1, 0, 0), dig(labeled, 2, 0), "Local variable a != block arg a"
    assert_equal dig(labeled, 4, 2, 2, 0), dig(labeled, 4, 1, 1, 0, 0), "Local variable a in block == block arg a"

    assert_equal dig(labeled, 4, 2, 3, 0), dig(labeled, 4, 1, 1, 1, 0), "Local variable b in block == block arg b"

    assert_equal dig(labeled, 4, 2, 4, 0), dig(labeled, 3, 0), "Local variable c in block == Local variable c in top level"
  end

  def test_rescue
    node = parse(<<-EOR)
e = 0
begin
  e
rescue => e
  e
end
e
    EOR

    labeled = Labeling.translate(node: node)

    assert_equal dig(labeled, 1, 0, 0, 0), dig(labeled, 0, 0), "e in begin == e in toplevel"
    assert_equal dig(labeled, 1, 0, 1, 1, 0), dig(labeled, 1, 0, 1, 2, 0), "e bound by rescue == e in rescue"
    assert_equal dig(labeled, 1, 0, 0, 0), dig(labeled, 0, 0), "e bound by rescue == e in toplevel"
    assert_equal dig(labeled, 1, 0, 0, 0), dig(labeled, 2, 0), "e bound by rescue == e in toplevel after rescue"
  end

  def test_module
    node = parse(<<-EOR)
a = 0
class A
  a = 2
  module B
    a = 3
  end
end
    EOR

    labeled = Labeling.translate(node: node)

    refute_equal dig(labeled, 0, 0), dig(labeled, 1, 2, 0, 0), "a in top != a in A"
    refute_equal dig(labeled, 0, 0), dig(labeled, 1, 2, 1, 1, 0), "a in top != a in A::B"
    refute_equal dig(labeled, 1, 2, 0, 0), dig(labeled, 1, 2, 1, 1, 0), "a in A != a in A::B"
  end

  def test_procarg0
    node = parse(<<-EOR)
foo do |(a, (b, c))| () end
    EOR

    labeled = Labeling.translate(node: node)

    assert_equal :a, dig(labeled, 1, 0, 0, 0).name
    assert_equal :b, dig(labeled, 1, 0, 1, 0, 0).name
    assert_equal :c, dig(labeled, 1, 0, 1, 1, 0).name
  end

  def test_match_with_lvasgn
    node = parse(<<-EOS)
x = 1
/(?<x>..)(?'y'..)/ =~ (foo = gets)
y = 2
    EOS

    labeled = Labeling.translate(node: node)
    match = dig(labeled, 1)

    assert_equal :x, dig(match, 2)[0].name
    assert_equal :y, dig(match, 2)[1].name

    assert_equal dig(labeled, 0, 0), dig(match, 2)[0]
    assert_equal dig(labeled, 2, 0), dig(match, 2)[1]
  end

  def test_extract_variables
    assert_equal [:x, :y], Labeling.extract_variables("(?<x>..)(?'y'..)")
  end
end
