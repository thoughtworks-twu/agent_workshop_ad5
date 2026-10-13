# Weather Assistant

Simple weather application of pydantic ai and UV.

UV is a new and lightweigh dependencies manager for Python.

## Prerequisites

This project is managed with **[uv](https://docs.astral.sh/uv/)**, Astral's Python package
and project manager. It is the only thing you need to install by hand — uv takes care of
Python itself, the virtual environment, and every dependency.

**With Homebrew**, if you prefer:

```bash
brew install uv
```

Check it worked (restart your terminal first, so the new PATH is picked up):

```bash
uv --version
```

**Weather API KEY**
Sign up to **[WEATHER API](https://www.weatherapi.com/signup.aspx)** to get the value for WEATHER_API_KEY needed for the .env file.

## Setup

Create a copy of the file **.env.example** -> **.env**

Then set your keys in .env:

```env
GOOGLE_API_KEY=your_google_api_key_here
WEATHER_API_KEY=your_weather_api_key_here
```

Then use UV to install dependencies

```bash
uv sync
```

## Running agents

```bash
uv run --active {python_file_name}.py
```
