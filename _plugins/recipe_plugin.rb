require "prawn"
require "prawn/measurement_extensions"
require "active_support/core_ext/string/strip"
require "active_support/core_ext/string/filters"

class RecipePdfPresenter
  DOCUMENT_MARGIN = 0.25.in

  DOCUMENT_PAGE_SIZE = [6.in, 4.in]

  DEFAULT_FONT_FAMILY = "DejaVuSansMono"
  DEFAULT_FONT_SIZE = 8
  DEFAULT_FONT_LEADING = 1

  COLUMNS = {
    ingredients: {
      position: [0, 230],
      dimensions: {
        width: 2.6125.in,
        height: 240
      },
    },
    directions: {
      position: [2.8875.in, 230],
      dimensions: {
        width: 2.6125.in,
        height: 240
      },
    },
  }

  FONT_MANIFEST = {
    "DejaVuSansMono" => {
      bold:        "_fonts/DejaVuSansMono-Bold.ttf",
      bold_italic: "_fonts/DejaVuSansMono-BoldOblique.ttf",
      italic:      "_fonts/DejaVuSansMono-Oblique.ttf",
      normal:      "_fonts/DejaVuSansMono.ttf",
    }
  }

  attr_reader :filename, :content

  def self.generate_all!(pages)
    pages.each do |page|
      new(page: page).tap do |generator|
        generator.to_pdf
        generator.cleanup!
      end
    end
  end

  def initialize(page:)
    @filename = page.destination("/").sub(/\.html\z/, ".pdf")
    @content  = File.read(page.path, **Jekyll::Utils.merged_file_read_opts(page.site, {}))
  end

  def ingredients
    @ingredients ||= begin
                       found = false
                       lines = []
                       content.lines.each do |l|
                         if found && l =~ /\A## /
                           break
                         end

                         if found && l.chomp != ""
                           lines << l.chomp.sub(/\A[-\*] /, "")
                         end

                         if l.chomp =~ /\A## Ingredients\z/
                           found = true
                         end
                       end
                       parse_markdown_emphasis lines.join("\n")
                     end
  end

  def directions
    @directions ||= begin
                      found = false
                      lines = []
                      content.lines.each do |l|
                        if found && l.chomp != "---"
                          lines << l.chomp
                        end
                        if l.chomp =~ /\A## Directions\z/
                          found = true
                        elsif l.chomp == "---"
                          break
                        end
                      end
                      out = lines.join("\n").strip.gsub(/\n\n/, "XXX").squish.gsub("XXX", "\n\n")
                      parse_markdown_emphasis out
                    end
  end

  def title
    @title ||= begin
                 line = content.lines.first {|l| l =~ /\A# /}
                 line.chomp[2..-1]
               end
  end

  def extra
    @extra ||= begin
                 found = false
                 lines = []
                 content.lines.each do |l|
                   if found
                     lines << l.chomp
                   end

                   if l.chomp == "---"
                     found = true
                   end
                 end
                 out = lines.join("\n").strip.gsub(/\n\n/, "XXX").squish.gsub("XXX", "\n\n")
                 parse_markdown_emphasis out
               end
  end

  def to_pdf
    opts = { page_size: DOCUMENT_PAGE_SIZE, margin: DOCUMENT_MARGIN }

    Prawn::Document.generate(filename, opts) do |pdf|
      pdf.font_families.update(FONT_MANIFEST)
      pdf.font DEFAULT_FONT_FAMILY, size: DEFAULT_FONT_SIZE

      pdf.text title, style: :bold
      pdf.default_leading DEFAULT_FONT_LEADING

      COLUMNS.each do |name, col|
        pdf.bounding_box(col[:position], col[:dimensions]) do
          pdf.text name.to_s.capitalize, style: :bold
          pdf.move_down 10
          pdf.text send(name), inline_format: true
        end
      end

      if extra.chomp != ""
        pdf.start_new_page
        pdf.text extra
      end
    end
  end

  def cleanup!
    md = filename.sub(/\.pdf\z/, ".md")
    txt = filename.sub(/\.pdf\z/, ".txt")
    File.rename(md, txt)
  end

  private

  def parse_markdown_emphasis(string)
    string
      .gsub(/^### (.*)$/, "\n<b>\\1</b>")
      .gsub(/\*\*([^\*]+)\*\*/, "<b>\\1</b>")
      .strip
  end
end


Jekyll::Hooks.register :site, :post_write do |site|
  recipes = site.pages.select { |page| page.data["recipe"] || page.data["cocktail"] }

  RecipePdfPresenter.generate_all!(recipes)
end

module Jekyll
  module Drops
    class StaticFileDrop
      def recipe_title
        return unless fallback_data["recipe"] || fallback_data["cocktail"]

        p = File.expand_path("../..#{path}", __FILE__)

        File.open(p, &:gets).sub(/\A# /, "")
      end
    end
  end
end

class OldUrlRewrite
  REDIRECT_TEMPLATE = <<~HTML
    <!DOCTYPE html>
    <html lang="en-US">
      <meta charset="utf-8">
      <title>Redirecting&hellip;</title>
      <link rel="canonical" href="{URL}">
      <script>location="{URL}"</script>
      <meta http-equiv="refresh" content="0; url={URL}">
      <meta name="robots" content="noindex">
      <h1>Redirecting&hellip;</h1>
      <a href="{URL}">Click here if you are not redirected.</a>
    </html>
  HTML

  URLS = {
  "Tortellini, Spinach, Chicken Soup.html" => "Tortellini-Spinach-Chicken-Soup.html",
  "Tailgate Chili.html" => "Tailgate-Chili.html",
  "Tangy Cucumber Salad.html" => "Tangy-Cucumber-Salad.html",
  "Tiktok Garlic Soup.html" => "Tiktok-Garlic-Soup.html",
  "Crunchy Noodle Salad.html" => "Crunchy-Noodle-Salad.html",
  "Dill Pickle Pasta Salad.html" => "Dill-Pickle-Pasta-Salad.html",
  "Rosemary Garlic White Bean Soup.html" => "Rosemary-Garlic-White-Bean-Soup.html",
  "Chicken Chili.html" => "Chicken-Chili.html",
  "Cowboy Caviar.html" => "Cowboy-Caviar.html",
  "Baked Potato Soup.html" => "Baked-Potato-Soup.html",
  "Chipotle Sauce.html" => "Chipotle-Sauce.html",
  "Pickled Onions.html" => "Pickled-Onions.html",
  "Spaghetti Sauce.html" => "Spaghetti-Sauce.html",
  "Slow Cooker Chili.html" => "Slow-Cooker-Chili.html",
  "Twice Baked Potato Casserole.html" => "Twice-Baked-Potato-Casserole.html",
  "Smothered Chicken and Rice.html" => "Smothered-Chicken-and-Rice.html",
  "Spaghetti alla Carbonara.html" => "Spaghetti-alla-Carbonara.html",
  "Mississippi Pot Roast Sliders.html" => "Mississippi-Pot-Roast-Sliders.html",
  "Pan Pizza.html" => "Pan-Pizza.html",
  "Smash Burgers.html" => "Smash-Burgers.html",
  "Mac and Cheese (Taco) (Casserole Crockpot).html" => "Mac-and-Cheese-Taco-Casserole-Crockpot.html",
  "Million Dollar Spaghetti.html" => "Million-Dollar-Spaghetti.html",
  "Mac and Cheese (Instant Pot).html" => "Mac-and-Cheese-Instant-Pot.html",
  "Mac and Cheese (Stovetop).html" => "Mac-and-Cheese-Stovetop.html",
  "Linguini Alfredo.html" => "Linguini-Alfredo.html",
  "Mac and Cheese (Baked).html" => "Mac-and-Cheese-Baked.html",
  "Mac and Cheese (Hamburger Helper) (Stovetop).html" => "Mac-and-Cheese-Hamburger-Helper-Stovetop.html",
  "KFC Bowls.html" => "KFC-Bowls.html",
  "Lasagna.html" => "Lasagna.html",
  "Enchiladas.html" => "Enchiladas.html",
  "Garlic Noodles.html" => "Garlic-Noodles.html",
  "Crunchy Chicken Ramen Stir Fry.html" => "Crunchy-Chicken-Ramen-Stir-Fry.html",
  "Donut Fried Chicken.html" => "Donut-Fried-Chicken.html",
  "Egg Roll in a Bowl.html" => "Egg-Roll-in-a-Bowl.html",
  "Crock Pot BBQ Chicken.html" => "Crock-Pot-BBQ-Chicken.html",
  "Crock Pot Shredded BBQ Beef.html" => "Crock-Pot-Shredded-BBQ-Beef.html",
  "Chicken Bacon Ranch Sandwiches.html" => "Chicken-Bacon-Ranch-Sandwiches.html",
  "Crack Chicken Pierogi Casserole.html" => "Crack-Chicken-Pierogi-Casserole.html",
  "Creamy Chicken and Cheese Burritos.html" => "Creamy-Chicken-and-Cheese-Burritos.html",
  "Butter Chicken.html" => "Butter-Chicken.html",
  "Cheeseburger Bombs.html" => "Cheeseburger-Bombs.html",
  "Chicken Bacon Ranch Pasta.html" => "Chicken-Bacon-Ranch-Pasta.html",
  "Baked Spicy Chicken Sandwiches.html" => "Baked-Spicy-Chicken-Sandwiches.html",
  "Baked Ziti.html" => "Baked-Ziti.html",
  "Air Fryer Chicken Thighs.html" => "Air-Fryer-Chicken-Thighs.html",
  "Baked Chicken Parmesan.html" => "Baked-Chicken-Parmesan.html",
  "Peanut Butter Temptations.html" => "Peanut-Butter-Temptations.html",
  "Chocolate Chip Cookies.html" => "Chocolate-Chip-Cookies.html",
  "Dirt Pudding.html" => "Dirt-Pudding.html",
  "Blackberry Cobbler.html" => "Blackberry-Cobbler.html",
  "Cornbread.html" => "Cornbread.html",
  "Garlic Bread.html" => "Garlic-Bread.html",
  "Crispy Oven Fries.html" => "Crispy-Oven-Fries.html",
  "Mashed Potatoes.html" => "Mashed-Potatoes.html",
  "Parmesan Roasted Potatoes.html" => "Parmesan-Roasted-Potatoes.html",
  "Soft Pretzels.html" => "Soft-Pretzels.html",
  "Baked Turkey Meatballs.html" => "Baked-Turkey-Meatballs.html",
  "Barbeque Chicken Nachos.html" => "Barbeque-Chicken-Nachos.html",
  "Buffalo Chicken Rangoons.html" => "Buffalo-Chicken-Rangoons.html",
  "Cast Iron Beer Cheese.html" => "Cast-Iron-Beer-Cheese.html"
  }

  def self.generate(site)
    URLS.each do |old_url, new_url|
      path = File.expand_path("../../_site/recipes/#{old_url}", __FILE__)

      next if File.exist?(path)

      File.open(path, "w") do |f|
        f.puts REDIRECT_TEMPLATE.gsub("{URL}", "#{site.config["url"]}/recipes/#{new_url}")
      end
    end
  end
end

Jekyll::Hooks.register :site, :post_write do |site|
  OldUrlRewrite.generate(site)
end
