//= require jquery3
//= require medium-zoom

// image zoom

var mzoom = mediumZoom('#zoom-bg', { background: '#212530' })

// https://github.com/francoischalifour/medium-zoom/issues/60#issuecomment-425376849

var handleKey = e => {
    const images = mzoom.getImages()
    const currentImageIndex = images.indexOf(mzoom.getZoomedImage())
    let target

    if (images.length <= 1) {
      return
    }

    switch (e.code) {
      case 'ArrowLeft':
        target = currentImageIndex - 1 < 0 ?
          images[images.length - 1] : images[currentImageIndex - 1]
        mzoom.close().then(() => {
          mzoom.open({
            target: target
          })
        })
        break;
      case 'ArrowRight':
        target = currentImageIndex + 1 >= images.length ?
          images[0] : images[currentImageIndex + 1]
        mzoom.close().then(() => {
          mzoom.open({
            target: target
          })
        })
        break;
      default:
        break;
    }
}

var attachKeyEvents = e => {
    document.addEventListener('keyup', handleKey, false)
}
var detachKeyEvents = e => {
    document.removeEventListener('keyup', handleKey, false)
}

mzoom.on('open', attachKeyEvents)
mzoom.on('close', detachKeyEvents)