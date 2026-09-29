import http from 'k6/http';
import { check } from 'k6';
import { Counter } from 'k6/metrics';

const successfulHolds = new Counter('successful_holds');
const baseUrl = __ENV.BASE_URL;
const showId = __ENV.SHOW_ID;
const seatId = __ENV.SEAT_ID;

export const options = {
  scenarios: {
    same_seat_burst: {
      executor: 'per-vu-iterations',
      vus: Number(__ENV.VUS || 500),
      iterations: 1,
      maxDuration: '2m',
    },
  },
  thresholds: {
    successful_holds: ['count==1'],
    http_req_failed: ['rate<0.01'],
  },
};

export default function () {
  const payload = JSON.stringify({
    showId,
    seatIds: [seatId],
    userId: `load-test-user-${__VU}`,
  });
  const response = http.post(`${baseUrl}/v1/holds`, payload, {
    headers: { 'Content-Type': 'application/json' },
    timeout: '30s',
  });

  if (response.status === 201) {
    successfulHolds.add(1);
  }

  check(response, {
    'hold is created or seat conflict returned': (res) => res.status === 201 || res.status === 409,
  });
}