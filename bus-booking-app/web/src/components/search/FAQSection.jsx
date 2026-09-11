import { useState } from 'react';

const FAQS = [
  {
    question: 'Can I reschedule my bus booking?',
    answer:
      'Yes. Keep your Booking Reference ID handy and ask our support assistant to reschedule — it will check the operator\'s policy and show you real alternative trips before confirming.'
  },
  {
    question: 'How do I cancel my ticket?',
    answer:
      'Provide your Booking Reference ID to our support assistant to check cancellation eligibility, cancel the booking, and see any applicable refund.'
  },
  {
    question: 'Can I choose my own seat while booking?',
    answer: 'Yes. After selecting a bus, you\'ll see a live seat map — available, booked, and blocked seats are all shown before you choose.'
  },
  {
    question: 'Is it safe to pay online on RoadLink?',
    answer: 'Payment details are never stored on our servers in plain text; this demo build simulates payment while the architecture is ready for a real gateway integration.'
  },
  {
    question: 'What if I miss my bus?',
    answer: 'Missed-departure policies vary by operator. Contact support with your Booking Reference ID and we\'ll confirm what options, if any, the operator allows.'
  },
  {
    question: 'How will I receive my ticket?',
    answer: 'Your Booking Reference ID, PNR, and full trip details are shown immediately on the confirmation page and sent to the email you provided.'
  }
];

export default function FAQSection() {
  const [openIndex, setOpenIndex] = useState(0);

  return (
    <section className="faq">
      <h2>Frequently Asked Questions</h2>
      <div className="faq__list">
        {FAQS.map((faq, index) => {
          const isOpen = openIndex === index;
          return (
            <div key={faq.question} className={`faq-item ${isOpen ? 'faq-item--open' : ''}`}>
              <button
                type="button"
                className="faq-item__question"
                onClick={() => setOpenIndex(isOpen ? -1 : index)}
                aria-expanded={isOpen}
              >
                {faq.question}
                <span className="faq-item__chevron">{isOpen ? '−' : '+'}</span>
              </button>
              {isOpen && <p className="faq-item__answer">{faq.answer}</p>}
            </div>
          );
        })}
      </div>
    </section>
  );
}
