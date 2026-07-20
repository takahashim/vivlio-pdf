# frozen_string_literal: true

require 'minitest/autorun'
require 'fileutils'
require 'tmpdir'
require 'hexapdf'
require 'vivlio/pdf'

# Characterisation tests for the bundled Vivliostyle Viewer.
#
# These do not test vivlio-pdf. They pin down how the vendored viewer treats a
# handful of CSS features that stylesheets built on this gem rely on, so that
# updating vendor/viewer tells us when that treatment changes.
#
# Some of them pin behaviour that is arguably wrong (see the "not supported"
# cases below). A failure there is good news, not a regression: it means the
# viewer improved and the workaround in the dependent stylesheet can go. Read a
# red build here as "revisit the workaround", never as "something broke".
#
# Each expectation was measured against viewer 2.44.1.
class TestViewerBehavior < Minitest::Test
  def setup
    @dir = Dir.mktmpdir('viewer-behavior')
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  # Renders +body+ with +css+ and returns the Result.
  def render(css, body, page: 'size: 100mm 100mm; margin: 10mm;')
    @seq = (@seq || 0) + 1
    html = <<~HTML
      <!DOCTYPE html><html lang="ja"><head><meta charset="utf-8"><title>t</title>
      <style>@page { #{page} } #{css}</style></head><body>#{body}</body></html>
    HTML
    source = File.join(@dir, "probe#{@seq}.html")
    File.write(source, html)
    @last = File.join(@dir, "probe#{@seq}.pdf")
    Vivlio::PDF.print(source: source, output: @last, outline: :none)
  end

  def pdf(result = nil)
    HexaPDF::Document.open(result ? result.path : @last)
  end

  # Width and height in mm of every image placed on the page, read off the
  # transformation matrix in effect where it is drawn.
  def image_sizes(page)
    ctm = [1.0, 0, 0, 1.0, 0, 0]
    stack = []
    operands = []
    sizes = []
    page.contents.scan(/(-?[\d.]+(?:[eE]-?\d+)?)|([A-Za-z*"']+)/) do
      if Regexp.last_match(1)
        operands << Regexp.last_match(1).to_f
        next
      end
      case Regexp.last_match(2)
      when 'q' then stack.push(ctm.dup)
      when 'Q' then ctm = stack.pop || ctm
      when 'cm' then ctm = multiply(operands.last(6), ctm) if operands.size >= 6
      when 'Do'
        sizes << [Math.sqrt((ctm[0]**2) + (ctm[1]**2)) * 25.4 / 72,
                  Math.sqrt((ctm[2]**2) + (ctm[3]**2)) * 25.4 / 72]
      end
      operands.clear
    end
    sizes
  end

  def multiply(m, n)
    [m[0] * n[0] + m[1] * n[2], m[0] * n[1] + m[1] * n[3],
     m[2] * n[0] + m[3] * n[2], m[2] * n[1] + m[3] * n[3],
     m[4] * n[0] + m[5] * n[2] + n[4], m[4] * n[1] + m[5] * n[3] + n[5]]
  end

  # A real, decodable greyscale PNG. It has to decode: the viewer only adjusts
  # an image once its fetcher reports "load".
  #
  # No pHYs chunk, deliberately -- the viewer does not read one. Only the
  # image-resolution property set in CSS reaches it, which is why the annotator
  # resolves the value itself instead of relying on `from-image`.
  def png(width: 1454, height: 100)
    require 'zlib'
    raw = ("\x00".b + ("\x00".b * width)) * height   # filter byte + one row of pixels
    chunks = [chunk('IHDR', [width, height, 8, 0, 0, 0, 0].pack('N2C5')),
              chunk('IDAT', Zlib::Deflate.deflate(raw)),
              chunk('IEND', '')]
    path = File.join(@dir, "img#{width}.png")
    File.binwrite(path, "\x89PNG\r\n\x1a\n".b + chunks.join)
    path
  end

  def chunk(type, body)
    [body.bytesize].pack('N') + type + body + [Zlib.crc32(type + body)].pack('N')
  end

  # --- supported: relied on directly ---------------------------------------

  # Q (1/4 mm) is how Japanese typesetting states type size and leading, so the
  # design layer of a stylesheet is written in it.
  def test_q_unit_is_a_length
    render('', '<p>x</p>', page: 'size: 520Q 400Q; margin: 0;')
    box = pdf.pages[0].box(:media)

    assert_in_delta 130.0, box.width * 25.4 / 72, 0.3   # 520Q
    assert_in_delta 100.0, box.height * 25.4 / 72, 0.3  # 400Q
  end

  # @font-face size-adjust is how a stylesheet corrects the apparent size of
  # Latin text against Japanese of the same em.
  def test_font_face_size_adjust_changes_layout
    face = lambda { |name, adjust|
      %(@font-face { font-family: "#{name}"; src: local("Times New Roman"); size-adjust: #{adjust}; })
    }
    line = 'Hamburgefonstiv Hamburgefonstiv Hamburgefonstiv Hamburgefonstiv'
    text = ("<p>#{line}</p>" * 20)

    plain = render("#{face.call('Plain', '100%')} p { font-family: 'Plain'; font-size: 8pt; margin: 0; }", text)
    wide = render("#{face.call('Wide', '250%')} p { font-family: 'Wide'; font-size: 8pt; margin: 0; }", text)

    assert_operator wide.pages, :>, plain.pages,
                    'size-adjust should make the text take more room'
  end

  # A named page wins over :left/:right, which is what keeps a full-bleed cover
  # from picking up the body margins.
  def test_named_page_beats_left_right
    css = <<~CSS
      @page :left { margin-left: 40mm; }
      @page :right { margin-left: 40mm; }
      @page bare { margin: 0; }
      .b { page: bare; break-before: page; }
      .b div { border: .5pt solid #000; height: 20mm; }
    CSS
    render(css, '<div>a</div><div class="b"><div></div></div>')
    widest = image_widths_or_rects(pdf.pages[1]).max

    assert_in_delta 100.0, widest, 1.0, 'the bare page should keep margin: 0'
  end

  # --- not supported: workarounds depend on these staying broken -----------

  # A stylesheet cannot derive line-height as a ratio of two lengths: the
  # declaration parses (CSS.supports says yes) but does not reach layout, and
  # lines collapse so the content never paginates. Leading is passed as a
  # length instead.
  def test_calc_dividing_lengths_does_not_reach_layout
    body = (1..120).map { |i| "<p>#{i}</p>" }.join
    css = ':root { --lh: 21.65Q; --fs: 13Q; } html { font-size: var(--fs); } p { margin: 0; '

    as_length = render("#{css}line-height: var(--lh); }", body)
    as_ratio = render("#{css}line-height: calc(var(--lh) / var(--fs)); }", body)

    assert_operator as_length.pages, :>, 1, 'a length leading paginates normally'
    assert_equal 1, as_ratio.pages,
                 'if this now paginates, the ratio form works: stylesheets may use it'
  end

  # @layer is not merely ignored -- the rules inside it are dropped. Stylesheets
  # must not use it, and cannot rely on layer order for overrides.
  def test_at_layer_discards_its_contents
    body = '<div>a</div><div class="b">b</div>'

    plain = render('div.b { break-before: page; }', body)
    layered = render('@layer { div.b { break-before: page; } }', body)

    assert_equal 2, plain.pages
    assert_equal 1, layered.pages,
                 'if this is now 2, @layer is honoured and can be used'
  end

  # image-resolution below 96dpi (which includes every image with no embedded
  # resolution, read as 72dpi) enlarges by setting min-width, and min-width
  # beats max-width in CSS -- so the figure escapes the measure entirely.
  # See modifyElemDimensionWithImageResolution in core/src/vivliostyle/vgen.ts.
  def test_image_resolution_below_96dpi_defeats_max_width
    css = 'img { max-width: 100%; height: auto; }'
    page = 'size: 182mm 257mm; margin: 30mm 26mm;'   # 130mm measure

    img = png   # 1454px: 384.7mm read as 96dpi, 512.9mm read as 72dpi

    above = render(css, %(<img src="#{img}" style="image-resolution: 144dpi">), page: page)
    below = render(css, %(<img src="#{img}" style="image-resolution: 72dpi">), page: page)

    assert_in_delta 130.0, image_sizes(pdf(above).pages[0])[0][0], 1.0,
                    'at or above 96dpi the measure still caps the figure'
    assert_operator image_sizes(pdf(below).pages[0])[0][0], :>, 200.0,
                    'if this is now capped at 130mm, the min-width workaround can go'
  end

  # The same bug has a way around it: a non-zero min-width sends the viewer down
  # the branch that sets width, where max-width applies again.
  def test_min_width_restores_the_cap_below_96dpi
    result = render('img { min-width: 1px; max-width: 100%; height: auto; }',
                    %(<img src="#{png}" style="image-resolution: 72dpi">),
                    page: 'size: 182mm 257mm; margin: 30mm 26mm;')

    assert_in_delta 130.0, image_sizes(pdf(result).pages[0])[0][0], 1.0
  end

  private

  # Widths in mm of the rectangles stroked or filled on the page.
  def image_widths_or_rects(page)
    ctm = [1.0, 0, 0, 1.0, 0, 0]
    stack = []
    operands = []
    widths = []
    page.contents.scan(/(-?[\d.]+(?:[eE]-?\d+)?)|([A-Za-z*"']+)/) do
      if Regexp.last_match(1)
        operands << Regexp.last_match(1).to_f
        next
      end
      case Regexp.last_match(2)
      when 'q' then stack.push(ctm.dup)
      when 'Q' then ctm = stack.pop || ctm
      when 'cm' then ctm = multiply(operands.last(6), ctm) if operands.size >= 6
      when 're' then widths << (operands[-2] * ctm[0]).abs * 25.4 / 72 if operands.size >= 4
      end
      operands.clear
    end
    widths.reject { |w| w > 101 }
  end
end
