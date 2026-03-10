# Matlab_Visualize

신호 처리 시각화/디버깅 워크플로우를 위한 모듈형 MATLAB 프로젝트입니다.

## 프로젝트 구조

- `src/app/`: 앱 셸 상태 및 워크플로우 오케스트레이션
- `src/pipeline/`: 처리 파이프라인 실행/검증
- `src/processing/`: 신호 처리 알고리즘 및 공간(베어링) 플레이스홀더
- `src/visualization/`: 렌더링 함수(1D 플롯 + 대시보드 셸)
- `src/io/`: 로깅 및 저장/내보내기 헬퍼
- `tests/`: MATLAB `matlab.unittest` 테스트 스위트
- `scripts/`: 개발용 스크립트
- `data/output/`: 생성 산출물(로그/내보내기 파일)

## 현재 앱 셸(1차)

- `create_app_state` 기반 공유 세션 상태
- `select_main_view` 기반 메인 뷰 전환
- 대시보드 구성
  - 단일 메인 뷰
  - 요약 카드
  - 프레임 품질 카드
  - 이벤트/상태 스트립
- 프레임 선택/스텝 이동 및 요약 동기화
- 렌더링 경로에서 FFT 재계산을 피하기 위한 캐시 기반 뷰 렌더링

## 현재 메인 뷰

- Spectrum
- Waterfall (프레임 인지 라벨, 롤링 히스토리, hold/overlay 마커)
- Peak Trend
- Compare (raw vs processed 신호 + 캐시 스펙트럼 오버레이)
- Frame Quality
- Bearing Map (플레이스홀더)
- Bearing Frequency (플레이스홀더)
- Bearing Time (플레이스홀더)

## 시작하기 (MATLAB)

```matlab
addpath('scripts')
setup_project_paths

run_smoke
run_all_tests
run_smoke_validation
```

MATLAB 런타임이 없는 환경에서는 정적 점검 스크립트를 사용하세요.

```bash
./scripts/run_static_checks.sh
```

## 로컬 검증 빠른 시작 (권장)

로컬에 저장소를 가져온 뒤 아래 순서로 확인하면 됩니다.

```matlab
addpath('scripts')
setup_project_paths

% 1) 빠른 점검(스모크 + export 확인)
summaryQuick = run_local_validation('quick')

% 2) 전체 점검(스모크 + matlab.unittest + selftest)
summaryFull = run_local_validation('full')
```

- `run_local_validation('quick')`는 `run_smoke`를 실행하고 산출물 경로(`state.last_exports`)를 요약합니다.
- `run_local_validation('full')`는 `run_all_tests`까지 수행합니다.
- 에러가 발생하면 해당 단계에서 즉시 중단(rethrow)되어 실패 지점을 바로 확인할 수 있습니다.

## 라이선스

Apache 2.0 (`LICENSE` 참고)

## 1차 헬퍼 함수

- `compute_frame_quality`
- `build_detection_summary`
- `update_event_log`

## 프리셋 동작(현재)

- `Quick Check`: 기본 뷰 `Spectrum`, threshold 비활성, summary/event 중심
- `Detection`: 기본 뷰 `Spectrum`, threshold 활성(`0.2`), summary+quality+event 중심
- `History`: 기본 뷰 `Waterfall`, threshold 비활성, main/event 중심
- `Debug`: 기본 뷰 `Frame Quality`, threshold 활성(`0.1`), quality 중심

`select_main_view`는 UI 상태만 변경하며 캐시 결과를 재사용합니다(FFT 재계산 없음).

## Compare 뷰 메모

- Compare 뷰는 `execute_pipeline`이 준비한 `result.compare`를 사용하며 렌더링에서 FFT를 재계산하지 않습니다.
- threshold pre/post 비교는 현재 부분적으로만 제공됩니다(`pre-threshold`만 캐시, `post-threshold`는 추후 구현).

## Waterfall 뷰 메모

- Waterfall은 `state.waterfall` 캐시(`magnitudeMatrix`, `frame_indices`)를 사용하며 렌더링에서 FFT를 재계산하지 않습니다.
- 현재 프레임 마커는 기본 활성화되어 있고, max-hold/mean-hold 오버레이는 `state.waterfall.overlay`로 제어합니다.
- 롤링 히스토리는 `state.waterfall.max_history_frames`(기본 `inf`)로 제어합니다.

## 함수 사용 예시 모음(종류별)

- 통합 예시 진입점: `scripts/example_function_groups_usage.m`
  - Category 1: App/Session + Pipeline
  - Category 2: Visualization + Export
  - Category 3: TCP metadata normalize
  - Category 4: RX callback wrappers (`eth_rx_save/log/plot/pipeline`)
  - Category 5: `EthTcpServer` + `schemaFromHeader/registerFromHeader` 오프라인 템플릿

```matlab
addpath(genpath('src'))
addpath('scripts')
example_function_groups_usage

% 수중 탐지 전시 데모 시나리오
stateDemo = example_underwater_exhibition_scenario
```

## 스냅샷/내보내기 메모

- `export_session_artifacts`로 현재 대시보드 그림(`.png`), 현재 결과(`.mat`), 전체 상태 스냅샷(`.mat`), 요약(`.csv`)을 저장합니다.
- 기본 출력 루트는 `data/output/`이며 하위 폴더는 `figures/`, `results/`, `snapshots/`, `summaries/`입니다.
- 내보내기 이벤트는 `state.event_log`에 기록되며 최신 경로는 `state.last_exports`에 저장됩니다.

## 하드닝 이후 보류 로드맵

- TCP 런타임 수신/버퍼링 연동
- Compare의 threshold post-stage 처리
- 베어링 맵 고도화(플레이스홀더 이후 알고리즘)
- 고급 인터랙션 및 멀티 세션/프로젝트 관리

## 미래 확장 인터페이스

- TCP 확장 인터페이스: `get_tcp_input_contract`, `parse_tcp_packet_metadata`, `update_tcp_packet_context`
- 공간/베어링 확장 뷰: `Bearing Frequency`, `Bearing Time` (기존 메인 뷰 시스템에서 선택 가능)
- 본 단계는 메타데이터/플레이스홀더 수준이며, 실시간 신호 체인과 최종 베어링 알고리즘은 의도적으로 미구현 상태입니다.


## TCP 수신 확장(신규)

- `EthTcpServer`: TCP 바이트 스트림 프레이밍(동기화/패킷 길이), 헤더/바디 디코딩, 헤더 기반 스키마 로더
- `schemaFromHeader`/`registerFromHeader`: `.h` 기반 스키마 자동 생성/토픽 등록
- 수신 콜백 헬퍼
  - `EthTcpStructRecorder`, `EthTcpSimpleLogger`
  - `eth_rx_save`, `eth_rx_log`, `eth_rx_plot`, `eth_rx_pipeline`
- 예시
  - `scripts/example_record_TestInputType.m`
  - `scripts/example_rx_tools_usage.m`
- 전시 시나리오 예시
  - `scripts/example_underwater_exhibition_scenario.m` (수중 탐지 데모: search/approach/classify 단계)
- 자기점검 스크립트
  - `tests/selftest_strip_preprocessor_and_schema.m`
  - `tests/selftest_nested_structs.m`
  - `tests/selftest_typedef_aliases.m`
  - `tests/selftest_multidim_pointer_schema.m`

주의: 본 단계는 TCP 런타임 신호 체인 전체 구현이 아니라, 수신/스키마/저장/로깅/플로팅 확장 인터페이스를 우선 통합한 단계입니다.
