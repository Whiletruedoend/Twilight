function run() {
    showdown.setFlavor('github');
    var text = document.getElementById('post_content').value,
        target = document.getElementById('preview'),
        converter = new showdown.Converter({smoothLivePreview: true}),
        html = converter.makeHtml(text);

    target.innerHTML = html;
}
