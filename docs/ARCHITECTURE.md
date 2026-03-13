# 아키텍처

이 저장소는 재사용 가능한 MATLAB 신호 처리 시각화/디버깅 애플리케이션으로 진화하는 것을 목표로 합니다.

## 레이어

- `src/app`: 앱 셸 상태, 프리셋, 프레임 선택/스텝, 프레임 업데이트 워크플로우
- `src/pipeline`: 입력 검증 및 핵심 처리 오케스트레이션
- `src/io`: 로깅 및 저장/내보내기
- `src/processing`: 결정론적 FFT/특징 추출 로직 및 공간 플레이스홀더
- `src/visualization`: 렌더링 전용 계층(플로팅 함수 내부 FFT 계산 금지)
- `src/config`: 설정 제공자 전용
- `src/utils`: 공용 헬퍼

## 현재 앱 셸(1차)

- 공유 앱/세션 상태
- 메인 뷰 선택기
- 요약 카드(1급 UI)
- 프레임 품질 카드(1급 UI)
- 이벤트/상태 스트립(최근 로그)

## 공유 상태 계약 (app shell)

`state` 필드:
- `current_view`
- `current_preset`
- `current_frame_idx`
- `selected_frame_idx`
- `threshold_enabled`
- `threshold_value`
- `panel_emphasis`
- `current_input`
- `current_result`
- `tcp`
  - `contract`
  - `enabled`
  - `last_packet_meta`
  - `packet_meta_history`
  - `status`
- `waterfall`
  - `frequencyHz`
  - `magnitudeMatrix`
  - `frame_indices`
  - `max_history_frames`
  - `hold_enabled`
  - `hold_frame_indices`
  - `overlay.showCurrentMarker`
  - `overlay.showMaxHold`
  - `overlay.showMeanHold`
- `frame_history`
- `quality_history`
- `detection_history`
- `peak_trend`
- `bearing` (플레이스홀더 계약)
- `frame_quality_summary`
- `detection_summary`
- `event_log`
- `last_update_time`
- `last_issue`
- `last_error_or_warning`
- `last_exports`

## 프리셋(현재)

- `Quick Check`: 기본 뷰 `Spectrum`, threshold 비활성
- `Detection`: 기본 뷰 `Spectrum`, threshold 활성(`0.2`)
- `History`: 기본 뷰 `Waterfall`, threshold 비활성
- `Debug`: 기본 뷰 `Frame Quality`, threshold 활성(`0.1`)

## 대시보드 메인 뷰

- Spectrum
- Waterfall (선택 프레임 마커 + hold 오버레이)
- Peak Trend
- Compare
- Frame Quality
- Bearing Map (플레이스홀더)
- Bearing Frequency (플레이스홀더)
- Bearing Time (플레이스홀더)

## Waterfall 캐시 계약

`state.waterfall`은 Waterfall UI가 소비하는 렌더링 캐시입니다.
- `frequencyHz`
- `magnitudeMatrix`
- `frame_indices`
- `max_history_frames`
- `hold_enabled`
- `hold_frame_indices`
- `overlay.showCurrentMarker`
- `overlay.showMaxHold`
- `overlay.showMeanHold`

이 구조는 Waterfall UX 개선을 렌더링/상태 계층에 국한하고, 기존 FFT 계산 경로를 보존합니다.

## Compare 파이프라인 계약

`execute_pipeline`은 렌더링 시 재계산 없이 사용할 수 있도록 `result.compare`를 캐시합니다.
- `signal.raw`
- `signal.processed`
- `signal.axis`
- `spectrum.raw`
- `spectrum.processed`
- `threshold.pre`
- `threshold.post` (현재 보류/비어 있음)
- `meta.thresholdComparisonAvailable`

즉, 비교 로직은 파이프라인 출력에 두고, 시각화 계층은 렌더링만 담당합니다.

## 의도적 보류 항목

- TCP 소켓 런타임 + 버퍼링 구현
- 패킷 메타데이터 전용 대시보드 뷰
- 베어링 처리 알고리즘 본 구현
- 고급 인터랙션 제어/멀티 윈도우 툴링
- 지속형 멀티 세션/프로젝트 관리

## 1차 헬퍼 책임

- `compute_frame_quality`: NaN/Inf, 클리핑, DC offset, RMS/에너지, 길이 유효성, decode/continuity 상태 계산
- `build_detection_summary`: 캐시된 peaks 기반 strongest peak, top-3, threshold margin 계산
- `update_event_log`: 구조화 이벤트 append 및 `last_update_time` 갱신

## 프리셋 + 메인 뷰 워크플로우

- 프리셋(`apply_preset`)은 다음을 정의
  - 기본 메인 뷰
  - threshold 표시/값
  - 패널 강조(`panel_emphasis`)
- 메인 뷰 전환(`select_main_view`)은 뷰/강조 상태만 업데이트하고 렌더러에서 캐시 데이터를 읽습니다.

## 스냅샷/내보내기 워크플로우

- `export_session_artifacts`는 처리/렌더링과 분리된 앱 셸 내보내기 오케스트레이션입니다.
- (figure handle이 있으면) 다음을 내보냅니다.
  - 대시보드 이미지(`.png`)
  - 현재 결과(`.mat`)
  - 전체 상태 스냅샷(`.mat`)
  - 요약(`.csv`)
- 내보내기 이벤트는 `update_event_log`로 기록되며 최신 경로는 `state.last_exports`에 캐시됩니다.

## 하드닝 이후 보류 로드맵

- TCP 런타임 수신 + 버퍼링
- Compare pre/post를 위한 threshold post-stage 처리
- 베어링 플레이스홀더 이후의 본 처리 알고리즘
- 고급 UI 인터랙션 및 멀티 세션/프로젝트 관리

## 미래 확장 인터페이스

- `get_tcp_input_contract`: 정규화 프레임 입력/메타데이터를 위한 TCP 어댑터 계약
- `parse_tcp_packet_metadata`: payload decode와 분리된 메타데이터 전용 파서
- `update_tcp_packet_context`: 앱 상태의 TCP 메타데이터 히스토리 갱신(실시간 수신기는 미구현)
- 메인 뷰 확장 포인트: `Bearing Frequency`, `Bearing Time` 플레이스홀더


## TCP 수신/스키마 확장(신규 통합)

- 핵심 클래스: `EthTcpServer`
  - TCP 버퍼 누적/동기화(StartCode)/패킷 길이(`unPacketSize`) 기반 프레이밍
  - 헤더 디코딩 + topic callback 라우팅
  - `meta.packetBytes`, `meta.packetByteCount`, `meta.packetSize`, `meta.packetCount`, `meta.topicId` 유지
- 헤더 파서
  - `schemaFromHeader`: define/typedef/중첩 struct/다차원 배열/포인터(opaque) 처리
  - preprocessor 라인은 라인 스캔 방식으로 제거(회귀 방지)
- 수신 콜백 도구
  - 저장: `EthTcpStructRecorder`, `eth_rx_save`
  - 로깅: `EthTcpSimpleLogger`, `eth_rx_log`
  - 플롯: `eth_rx_plot`
  - 통합: `eth_rx_pipeline`

제한(명시적): 함수 포인터, 비트필드, 복잡 선언자는 명시적으로 미지원 오류 처리합니다.
