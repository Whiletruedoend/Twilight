
// showdown

showdown.setOption('strikethrough', 'true');
showdown.setOption('smartIndentationFix', 'true');
showdown.setFlavor('github');

var text = document.getElementById('post_content').value,
    target = document.getElementById('preview'),
    converter = new showdown.Converter(),
    html = converter.makeHtml(text);
target.innerHTML = html;

// Auto-preview

var post = document.getElementById('post_content');

post.onkeyup = post.onkeypress = function(){
    document.getElementById('preview').innerHTML = converter.makeHtml(this.value);
}