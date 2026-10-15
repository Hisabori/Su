{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    try {
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
      document.getElementById('loading')?.remove();
    } catch (_) {
      const text = document.getElementById('loading-text');
      if (text) text.textContent = '앱을 열지 못했습니다. 최신 브라우저에서 다시 시도해 주세요.';
      const reload = document.getElementById('reload');
      if (reload) reload.style.display = 'inline-block';
    }
  }
});
