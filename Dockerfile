# syntax=docker/dockerfile:1
ARG PYTHON_VERSION=3.14
FROM ghcr.io/astral-sh/uv:python$PYTHON_VERSION-bookworm-slim AS builder
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy UV_PYTHON_DOWNLOADS=0

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc python3-dev libc6-dev git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
RUN git clone --depth 1 https://github.com/PasarGuard/panel.git .

# پچ ۱: باگ فعلی برنچ main پاسارگارد -- سینتکس پایتون ۲ که در پایتون ۳ SyntaxError می‌دهد
# و باعث می‌شود کل main.py اصلاً اجرا نشود (کرش کامل هنگام استارت).
RUN sed -i 's/except ValueError, socket.gaierror:/except (ValueError, socket.gaierror):/' main.py

# پچ ۲: بدون SSL، پاسارگارد به‌صورت پیش‌فرض روی localhost گوش می‌دهد که در Railway
# باعث "Application failed to respond" می‌شود؛ این پچ همیشه 0.0.0.0 را اجباری می‌کند.
RUN sed -i 's/bind_args\["host"\] = ip/bind_args["host"] = server_settings.host/' main.py

RUN uv sync --frozen --no-dev

FROM python:$PYTHON_VERSION-slim-bookworm
COPY --from=builder /build /code
WORKDIR /code
ENV PATH="/code/.venv/bin:$PATH"

RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

COPY start-railway.sh /start-railway.sh
RUN chmod +x /start-railway.sh /code/start.sh

# این خط به Railway می‌گوید پنل روی کدام پورت گوش می‌دهد تا موقع ساخت
# دامنه، پورت درست را خودش به‌صورت خودکار تشخیص دهد.
EXPOSE 8000

ENTRYPOINT ["/start-railway.sh"]
