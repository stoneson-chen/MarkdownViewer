import Testing
@testable import MarkdownViewer

@Suite
struct MarkdownParserTests {
    let parser = MarkdownParser()

    @Test
    func headings() async {
        let result = await parser.parse("# H1\n## H2\n### H3\n#### H4\n##### H5\n###### H6")
        #expect(result.headings.count == 6)
        #expect(result.headings[0].level == 1)
        #expect(result.headings[0].text == "H1")
        #expect(result.headings[1].level == 2)
        #expect(result.headings[5].level == 6)
    }

    @Test
    func notHeading() async {
        let result = await parser.parse("###not a heading")
        #expect(result.headings.isEmpty)
    }

    @Test
    func inlineFormatting() async {
        #expect(await parser.parse("**bold text**").html.contains("<strong>bold text</strong>"))
        #expect(await parser.parse("*italic text*").html.contains("<em>italic text</em>"))
        #expect(await parser.parse("use `print()` function").html.contains("<code>print()</code>"))
        #expect(await parser.parse("~~deleted~~").html.contains("<del>deleted</del>"))
    }

    @Test
    func linksAndImages() async {
        let link = await parser.parse("[Example](https://example.com)")
        #expect(link.html.contains("<a href=\"https://example.com\" target=\"_blank\" rel=\"noopener\">Example</a>"))

        let image = await parser.parse("![Alt](image.png)")
        #expect(image.html.contains("<img src=\"image.png\" alt=\"Alt\">"))
    }

    @Test
    func codeBlocks() async {
        let plain = await parser.parse("```\nlet x = 1\n```")
        #expect(plain.html.contains("<pre><code class=\"language-\">let x = 1"))

        let swift = await parser.parse("```swift\nlet x = 1\n```")
        #expect(swift.html.contains("<pre><code class=\"language-swift\">"))
    }

    @Test
    func blockquotes() async {
        let result = await parser.parse("> quoted text")
        #expect(result.html.contains("<blockquote><p>quoted text</p></blockquote>"))
    }

    @Test
    func lists() async {
        let unordered = await parser.parse("- item 1\n- item 2")
        #expect(unordered.html.contains("<ul>"))
        #expect(unordered.html.contains("<li>item 1</li>"))
        #expect(unordered.html.contains("<li>item 2</li>"))

        let ordered = await parser.parse("1. first\n2. second")
        #expect(ordered.html.contains("<ol start=\"1\">"))
        #expect(ordered.html.contains("<li>first</li>"))
        #expect(ordered.html.contains("<li>second</li>"))

        let tasks = await parser.parse("- [x] done\n- [ ] todo")
        #expect(tasks.html.contains("checked disabled"))
        #expect(tasks.html.contains("todo"))
    }

    @Test
    func tables() async {
        let result = await parser.parse("| A | B |\n| - | - |\n| 1 | 2 |")
        #expect(result.html.contains("<table>"))
        #expect(result.html.contains("<th>A</th>"))
        #expect(result.html.contains("<td>1</td>"))
    }

    @Test
    func wordCount() async {
        #expect(await parser.parse("Hello world, this is a test.").wordCount == 6)
        #expect(await parser.parse("").wordCount == 0)
    }

    @Test
    func htmlEscaping() async {
        let result = await parser.parse("5 < 10 & 3 > 1")
        #expect(result.html.contains("5 &lt; 10 &amp; 3 &gt; 1"))
    }
}
