# frozen_string_literal: true

module DocumentsHelper
  def status_badge_classes(status)
    {
      'pending' => 'bg-gray-100 text-gray-600',
      'processing' => 'bg-yellow-100 text-yellow-700',
      'ready' => 'bg-green-100 text-green-700',
      'failed' => 'bg-red-100 text-red-700'
    }.fetch(status.to_s, 'bg-gray-100 text-gray-600')
  end
end
