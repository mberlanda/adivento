class JsonWebToken
  SECRET = ENV.fetch("JWT_SECRET", "dev-only-secret-change-me")

  def self.encode(payload, expires_at: 24.hours.from_now)
    JWT.encode(payload.merge(exp: expires_at.to_i), SECRET, "HS256")
  end

  def self.decode(token)
    JWT.decode(token, SECRET, true, algorithm: "HS256").first
  end
end
